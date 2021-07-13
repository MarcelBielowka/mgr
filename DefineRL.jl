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

    if iHour !=23
        Microgrid.State = vcat([
            iTotalProduction
            iTotalConsumption
            iProductionConsumptionMismatch
            Microgrid.EnergyStorage.iCurrentCharge
            ], @pipe Flux.onehot(iHour, collect(0:22)) |> collect(_) |> Int.(_))
    else
        Microgrid.State = vcat([
            iTotalProduction
            iTotalConsumption
            iProductionConsumptionMismatch
            Microgrid.EnergyStorage.iCurrentCharge
            ], repeat([0], 23))
    end
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

function ActorLoss(x, Actions, A; ι::Float64 = 0.001, iσFixed::Float64 = 0.2)
    μ_policy = FullMicrogrid.Brain.policy_net(x)
    println("μ_policy: $μ_policy")
    #println(typeof(μ_policy))
    Policy = Distributions.Normal.(μ_policy, iσFixed)
    println("Policy: $Policy")
    iScoreFunction = -Distributions.logpdf.(Policy, Actions)
    println("iScoreFunction: $iScoreFunction")
    iLoss = sum(iScoreFunction .* A) / size(A,1)
    println("Loss function: $iLoss")
    return iLoss
end

function CriticLoss(x, y; ξ = 0.5)
    return ξ*Flux.mse(FullMicrogrid.Brain.value_net(x), y)
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
    return Action, ActualAction
end

function CalculateReward(Microgrid::Microgrid, Action::Float64, ActualAction::Float64, iTimeStep::Int64)
    if abs(Action / ActualAction) > 2
        return -1e6
    end
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

function Replay!(Microgrid::Microgrid)
    println("Start learning")
    x = zeros(Float64, length(Microgrid.State), Microgrid.Brain.batch_size)
    Actions = zeros(Float64, 1, Microgrid.Brain.batch_size)
    A = zeros(Float64, 1, Microgrid.Brain.batch_size)
    y = zeros(Float64, 1, Microgrid.Brain.batch_size)
    iter = @pipe sample(Microgrid.Brain.memory, Microgrid.Brain.batch_size, replace = false) |>
        enumerate |> collect
    for (i, step) in iter
        State, Action, Reward, NextState, v, v′, bTerminal = step
        if !bTerminal
            R = Reward
        else
            R = Reward + Microgrid.Brain.β * v′
        end
        iAdvantage = R - v
        x[:, i] .= State
        A[:, i] .= iAdvantage
        Actions[:,i] .= Action
        y[:, i] .= R

    end

    Flux.train!(ActorLoss, Flux.params(Microgrid.Brain.policy_net), [(x,Actions,A)], ADAM(Microgrid.Brain.ηₚ))
    Flux.train!(CriticLoss, Flux.params(Microgrid.Brain.value_net), [(x,y)], ADAM(Microgrid.Brain.ηᵥ))
end


function Act!(Microgrid::Microgrid, iTimeStep::Int, iHorizon::Int, bLearn::Bool)
    #Random.seed!(72945)
    CurrentState = deepcopy(Microgrid.State)
    Policy, v = Forward(Microgrid, CurrentState, true)
    Action = rand(Policy)
    println("We're in time step $iTimeStep and the intended action is $Action. This equals to an intended charge/discharge of ", Action * CurrentState[3])

    #if CurrentState.dictProductionAndConsumption.iProductionConsumptionMismatch >= 0
    Action, ActualAction = ChargeOrDischargeBattery!(Microgrid, Action)
    iReward = CalculateReward(Microgrid, Action, ActualAction, iTimeStep)

    NextState = GetState(Microgrid, iTimeStep + 1)
    Microgrid.State = NextState
    Microgrid.Reward += iReward
    _, v′ = Forward(Microgrid, NextState, true)
    if iTimeStep + 1 == iHorizon
        bTerminal = true
    else
        bTerminal = false
    end
    Remember!(Microgrid, (CurrentState,Action,iReward,NextState,v,v′,bTerminal))

    if (bLearn && length(Microgrid.Brain.memory) > Microgrid.Brain.min_memory_size)
        Replay!(Microgrid)
    end

    return bTerminal

    #return Dict(
    #    "CurrentState" => CurrentState,
    #    "ActualAction" => ActualAction,
    #    "iReward" => iReward,
    #    "NextState" => NextState
    #    )
end

function Run!(Microgrid::Microgrid, iNumberOfEpisodes::Int,
    iTimeStepStart::Int, iTimeStepEnd::Int, bLearn::Bool)
    iRewards = []
    restart!(Microgrid,iTimeStepStart)
    for iEpisode in 1:iNumberOfEpisodes
        for iTimeStep in iTimeStepStart:1:(iTimeStepEnd-1)
            bTerminal = Act!(Microgrid, iTimeStep, iTimeStepEnd, true)
            if bTerminal
                push!(iRewards, Microgrid.Reward)
                restart!(Microgrid,iTimeStepStart)
            end
        end
    end
    return iRewards
end
