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
    iPriceBuy = filter(row -> row.DeliveryHour == iHour,
        Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices).iThirdQuartile[1]
    iPriceSell = filter(row -> row.DeliveryHour == iHour,
        Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices).iFirstQuartile[1]
    iHours = @pipe Flux.onehot(iHour, collect(0:23)) |> collect(_) |> Int.(_)

    return vcat([
        iTotalProduction
        iTotalConsumption
        iProductionConsumptionMismatch
        iPriceBuy
        iPriceSell
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

function GetAction(Microgrid::Microgrid, Policy::Distribution)
    action = rand(Policy)
    return action
end

function ChargeOrDischargeBattery!(Microgrid::Microgrid, State::Vector, Action::Float64)
    iConsumptionMismatch = State[3]
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
            Microgrid.EnergyStorage.iCurrentCharge)
        iDischarge = max(iMaxPossibleDischarge, iChargeDischargeVolume)
        Microgrid.EnergyStorage.iCurrentCharge += iDischarge
        ActualAction = iDischarge / iConsumptionMismatch
        println("The actual discharge of the battery is $iDischarge, equivalent to action $ActualAction ")
    end
    return ActualAction
end

function CalculateReward(Microgrid::Microgrid, State::Vector, Action::Float64)
    iGridVolume = (1 - Action) * State[3]
    if iGridVolume >= 0
        iReward = iGridVolume * State[4]
    else
        iReward = iGridVolume * State[5]
    end
    return iReward
end


function Act!(Microgrid::Microgrid, CurrentState::Vector, iTimeStep::Int64)
    #Random.seed!(72945)
    Action = rand(Policy)
    println("We're in time step $iTimeStep and the intended action is $Action")
    println(Action)

    #if CurrentState.dictProductionAndConsumption.iProductionConsumptionMismatch >= 0
    ActualAction = ChargeOrDischargeBattery!(Microgrid, CurrentState, Action)
    iReward = CalculateReward(Microgrid, CurrentState, ActualAction)
    return Dict(
        "ActualAction" => ActualAction,
        "iReward" => iReward)

end

Random.seed!(72945)

GetState(FullMicrogrid,1)
testState = GetState(FullMicrogrid,1)
testAction = GetAction(FullMicrogrid, Policy)
Juno.@enter Act!(FullMicrogrid, testState, 1)

FullMicrogrid.EnergyStorage
