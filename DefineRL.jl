using Distributions
using Flux


Policy = Distributions.Normal(1.0, .1)
Action = rand(Policy)
pdf(Actions, Action)
pdf(Policy, 0.05)


mutable struct State
    dictProductionAndConsumption::Dict
    iPrices::Dict
    iCurrentCharge::Float64
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

    return State(
        Dict(
            "iTotalProduction" => iTotalProduction,
            "iTotalConsumption" => iTotalConsumption,
            "iProductionConsumptionMismatch" => iProductionConsumptionMismatch
        ),
        Dict(
            "iPriceBuy" => iPriceBuy,
            "iPriceSell" => iPriceSell
        ),
        Microgrid.EnergyStorage.iCurrentCharge
    )
end

function GetAction(Microgrid::Microgrid, Policy::Distribution)
    action = rand(Policy)
    return action
end

function Act!(Microgrid::Microgrid, action::Float64, iTimeStep::Int64)


    #return(Dict("iPriceBuy" => iPriceBuy, "iPriceSell" => iPriceSell))


end

GetState(FullMicrogrid,23)
testAction = GetAction(FullMicrogrid, Policy)
Act!(FullMicrogrid, testAction, 23)



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
