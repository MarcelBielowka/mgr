using Distributions, DataFrames
using Flux


Policy = Distributions.Normal(0.5, .1)
Action = rand(Policy)
pdf(Actions, Action)
pdf(Policy, 0.05)


mutable struct State
    dictProductionAndConsumption::Dict
    iBuyPrice::Float64
    iSellPrice::Float64
    iCurrentCharge::Float64
    iHour::BitArray
end

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

function ChargeOrDischargeBattery!(Microgrid::Microgrid,
    Action::Float64,
    iConsumptionMismatch::Float64)
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

function Act!(Microgrid::Microgrid, CurrentState::Vector, iTimeStep::Int64)
    Random.seed!(72945)
    Action = rand(Policy)
    println(Action)

    #if CurrentState.dictProductionAndConsumption.iProductionConsumptionMismatch >= 0
    AcutalAction = ChargeOrDischargeBattery!(Microgrid, Action, CurrentState[3])


end

GetState(FullMicrogrid,1)
testState = GetState(FullMicrogrid,1)
testAction = GetAction(FullMicrogrid, Policy)
Act!(FullMicrogrid, testState, 1)

FullMicrogrid.EnergyStorage

#########################################
######## Brain class definition #########
#########################################
mutable struct Brain
    β::Float64
    batch_size::Int
    memory_size::Int
    min_memory_size::Int
    memory::Array{Tuple,1}
    policy_net::Chain
    value_net::Chain
    ηₚ::Float64
    ηᵥ::Float64
end

function Brain(env; β = 1, ηₚ = 0.00001, ηᵥ = 0.001)
    policy_net = Chain(Dense(length(env.state), 40, identity),
                Dense(40,40,identity),
                Dense(40,1,identity))
    value_net = Chain(Dense(length(env.state), 128, relu),
                    Dense(128, 52, relu),
                    Dense(52, 1, identity))
    Brain(β, 64 , 50_000, 1000, [], policy_net, value_net, ηₚ, ηᵥ)
end

@pipe Flux.onehot(6, collect(0:23)) |> collect(_) |> Int.(_)
