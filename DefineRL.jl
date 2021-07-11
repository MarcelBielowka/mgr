using Distributions, DataFrames
using Flux


#ExamplePolicy = Distributions.Normal(0, .1)
#Action = rand(Policy)


#mutable struct State
#    dictProductionAndConsumption::Dict
#    iBuyPrice::Float64
#    iSellPrice::Float64
#    iCurrentCharge::Float64
#    iHour::BitArray
#end

function GetState(Microgrid::Microgrid, iTimeStep::Int64)
    iTotalProduction = Microgrid.dfTotalProduction.TotalProduction[iTimeStep,]
    iTotalConsumption = Microgrid.dfTotalConsumption.TotalConsumption[iTimeStep,]
    iProductionConsumptionMismatch = iTotalProduction - iTotalConsumption
    iHour = Dates.hour(Microgrid.dfTotalProduction.date[iTimeStep])
    iHours = @pipe Flux.onehot(iHour, collect(0:23)) |> collect(_) |> Int.(_)

    Microgrid.State = vcat([
        iTotalProduction
        iTotalConsumption
        iProductionConsumptionMismatch
        Microgrid.EnergyStorage.iCurrentCharge
    ], @pipe Flux.onehot(iHour, collect(0:23)) |> collect(_) |> Int.(_))
    #return State(
    #    Dict(
    #        "iTotalProduction" => iTotalProduction,
    #        "iTotalConsumption" => iTotalConsumption,
    #        "iProductionConsumptionMismatch" => iProductionConsumptionMismatch
    #    ),
    #    iPriceBuy,
    #    iPriceSell,
    #    Microgrid.EnergyStorage.iCurrentCharge
    #)
end

function restart!(Microgrid::Microgrid, iInitTimeStep::Int)
    Microgrid.Reward = 0
    Microgrid.EnergyStorage.iCurrentCharge = 0
    GetState(Microgrid, iInitTimeStep)
end

function GetAction(Microgrid::Microgrid, Policy::Distribution)
    action = rand(Policy)
    return action
end

function GetReward(Microgrid::Microgrid, iTimeStep::Int)
    iHour = Dates.hour(Microgrid.dfTotalProduction.date[iTimeStep])
    iPriceBuy = filter(row -> row.DeliveryHour == iHour,
        Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices).iThirdQuartile[1]
    iPriceSell = filter(row -> row.DeliveryHour == iHour,
        Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices).iFirstQuartile[1]
    return Dict(
        "iPriceBuy" => iPriceBuy,
        "iPriceSell" => iPriceSell
    )
end

function ChargeOrDischargeBattery!(Microgrid::Microgrid, Action::Float64)
    iConsumptionMismatch = Microgrid.State[3]
    iChargeDischargeVolume = Action * iConsumptionMismatch
    if iChargeDischargeVolume >= 0
        iMaxPossibleCharge = min(Microgrid.EnergyStorage.iChargeRate,
            Microgrid.EnergyStorage.iMaxCapacity - Microgrid.EnergyStorage.iCurrentCharge)
        iCharge = min(iMaxPossibleCharge, iChargeDischargeVolume)
        Microgrid.EnergyStorage.iCurrentCharge += iCharge
        ActualAction = iCharge / iConsumptionMismatch
        println("The actual charge of the battery is $iCharge, equivalent to action $ActualAction ")
    else
        iMaxPossibleDischarge = max(Microgrid.EnergyStorage.iDischargeRate,
            -Microgrid.EnergyStorage.iCurrentCharge)
        iDischarge = max(iMaxPossibleDischarge, iChargeDischargeVolume)
        Microgrid.EnergyStorage.iCurrentCharge += iDischarge
        ActualAction = iDischarge / iConsumptionMismatch
        println("The actual discharge of the battery is $iDischarge, equivalent to action $ActualAction ")
    end
    if ActualAction / Action < 0
        ActualAction = -ActualAction
    end
    t = 3
    return ActualAction
end

function CalculateReward(Microgrid::Microgrid, Action::Float64, iTimeStep::Int64)
    iGridVolume = (1 - Action) * Microgrid.State[3]
    dictRewards = GetReward(Microgrid, iTimeStep)
    if iGridVolume >= 0
        iReward = iGridVolume * dictRewards["iPriceSell"]
    else
        iReward = iGridVolume * dictRewards["iPriceBuy"]
    end
    return iReward
end

# update pamieci
function Remember!(Microgrid::Microgrid, step::Tuple)
    length(Microgrid.Brain.memory) == Microgrid.Brain.memory_size && deleteat!(Microgrid.Brain.memory,1)
    push!(Microgrid.Brain.memory, step)
end

# definicja, ktore kroki mamy wykonac
# bierze siec neuronowa i zwraca jej wynik
function Forward(Microgrid::Microgrid, state::Vector, bσFixed::Bool; iσFixed::Float64 = 0.2)
    μ_policy = Microgrid.Brain.policy_net(state)[1]    # wektor p-w na bazie sieci aktora
    if bσFixed
        Policy = Distributions.Normal(μ_policy, iσFixed)
    else
        println("Not yet implemented")
        return nothing
    end
    v = Microgrid.Brain.value_net(state)[1]   # wektor f wartosic na bazie sieci krytyka
    return Policy,v
end

function Act!(Microgrid::Microgrid, iTimeStep::Int, iHorizon::Int)
    #Random.seed!(72945)
    CurrentState = deepcopy(Microgrid.State)
    Policy, v = Forward(Microgrid, CurrentState, true)
    Action = rand(Policy)
    println("We're in time step $iTimeStep and the intended action is $Action")

    #if CurrentState.dictProductionAndConsumption.iProductionConsumptionMismatch >= 0
    ActualAction = ChargeOrDischargeBattery!(Microgrid, Action)
    iReward = CalculateReward(Microgrid, ActualAction, iTimeStep)

    NextState = GetState(Microgrid, iTimeStep + 1)
    Microgrid.State = NextState
    Microgrid.Reward += iReward
    _, v′ = Forward(Microgrid, NextState, true)
    if iTimeStep + 1 == iHorizon
        bTerminal = true
    else
        bTerminal = false
    end
    Remember!(Microgrid, (CurrentState,ActualAction,iReward,NextState,v,v′,bTerminal))

    return bTerminal

    #return Dict(
    #    "CurrentState" => CurrentState,
    #    "ActualAction" => ActualAction,
    #    "iReward" => iReward,
    #    "NextState" => NextState
    #    )
end

function Run!(Microgrid::Microgrid, iNumberOfEpisodes::Int,
    iTimeStepStart::Int, iTimeStepEnd::Int)
    iRewards = []
    restart!(Microgrid,iTimeStepStart)
    for iEpisode in 1:iNumberOfEpisodes
        for iTimeStep in iTimeStepStart:1:(iTimeStepEnd-1)
            bTerminal = Act!(Microgrid, iTimeStep, iTimeStepEnd)
            if bTerminal
                push!(iRewards, Microgrid.Reward)
                restart!(Microgrid,iTimeStepStart)
            end
        end
    end
    return iRewards
end

Random.seed!(72945)
restart!(FullMicrogrid, 1)
#Juno.@enter Run!(FullMicrogrid, 1, 1, 20)
Run!(FullMicrogrid, 1, 1, 20)

#GetState(FullMicrogrid,1)
#testState = GetState(FullMicrogrid,1)
#testAction = GetAction(FullMicrogrid, ExamplePolicy)
#a = Act!(FullMicrogrid, 2, 10)
#FullMicrogrid.State
#FullMicrogrid.Reward

FullMicrogrid.DayAheadPricesHandler.dfQuantilesOfPrices
FullMicrogrid.Brain.memory[19]

#CalculateReward(FullMicrogrid, 0.0, 1)
