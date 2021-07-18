using Distributions, Dates, DataFrames
using Flux, Pipe


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
            #iTotalProduction
            #iTotalConsumption
            iProductionConsumptionMismatch
            Microgrid.EnergyStorage.iCurrentCharge
            ], @pipe Flux.onehot(iHour, collect(0:22)) |> collect(_) |> Int.(_))
    else
        Microgrid.State = vcat([
            #iTotalProduction
            #iTotalConsumption
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

function GetParamsForNormalisation(Microgrid::Microgrid)
    iOverallConsMismatch = Microgrid.dfTotalProduction.TotalProduction - Microgrid.dfTotalConsumption.TotalConsumption
    return Dict(
    #    "ProductionScalingParams" => extrema(Microgrid.dfTotalProduction.TotalProduction),
    #    "ConsumptionScalingParams" => extrema(Microgrid.dfTotalConsumption.TotalConsumption),
        "ConsMismatchParams" => extrema(iOverallConsMismatch),
        "ChargeParams" => (0, Microgrid.EnergyStorage.iMaxCapacity)
    )
end

function NormaliseState!(State::Vector, Params::Dict)
    #(iProdMin, iProdMax) = Params["ProductionScalingParams"]
    #(iConsMin, iConsMax) = Params["ConsumptionScalingParams"]
    (iMismatchMin, iMismatchMax) = Params["ConsMismatchParams"]
    (iChargeMin, iChargeMax) = Params["ChargeParams"]
    #State[1] = (State[1] - iProdMin) / (iProdMax - iProdMin)
    #State[2] = (State[2] - iConsMin) / (iConsMax - iConsMin)
    #State[3] = (State[3] - iChargeMin) / (iChargeMax - iChargeMin)
    State[1] = (State[1] - iMismatchMin) / (iMismatchMax - iMismatchMin)
    State[2] = (State[2] - iChargeMin) / (iChargeMax - iChargeMin)
    return State
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

function ActorLoss(μ_hat, Actions, A; ι::Float64 = 0.001, iσFixed::Float64 = 8.0)
    # μ_policy = MyMicrogrid.Brain.policy_net(x)
    #println("μ_policy: $μ_policy")
    #println(typeof(μ_policy))
    Policy = Distributions.Normal.(μ_hat, iσFixed)
    #println("Policy: $Policy")
    iScoreFunction = -Distributions.logpdf.(Policy, Actions)
    #println("iScoreFunction: $iScoreFunction")
    iLoss = sum(iScoreFunction .* A) / size(A,1)
    # println("Loss function: $iLoss")
    return iLoss
end

function CriticLoss(ŷ, y; ξ = 0.5)
    return ξ*Flux.mse(ŷ, y)
end

function Replay!(Microgrid::Microgrid, dictNormParams::Dict)
    # println("Start learning")
    x = zeros(Float64, length(Microgrid.State), Microgrid.Brain.batch_size)
    μ_hat = zeros(Float64, 1, Microgrid.Brain.batch_size)
    ŷ = zeros(Float64, 1, Microgrid.Brain.batch_size)
    Actions = zeros(Float64, 1, Microgrid.Brain.batch_size)
    A = zeros(Float64, 1, Microgrid.Brain.batch_size)
    y = zeros(Float64, 1, Microgrid.Brain.batch_size)
    iter = @pipe sample(Microgrid.Brain.memory, Microgrid.Brain.batch_size, replace = false) |>
        enumerate |> collect
    for (i, step) in iter
        State, Action, ActualAction, Reward, NextState, v, v′, bTerminal = step
        if bTerminal
            R = Reward
        else
            R = Reward + Microgrid.Brain.β * v′
        end
        iAdvantage = R - v
        StateForLearning = @pipe deepcopy(State) |> NormaliseState!(_, dictNormParams)
        x[:, i] .= StateForLearning
        μ_hat[:, i] = Microgrid.Brain.policy_net(StateForLearning)
        ŷ[:, i] = Microgrid.Brain.value_net(StateForLearning)
        A[:, i] .= iAdvantage
        Actions[:,i] .= Action
        y[:, i] .= R
    end

    Flux.train!(ActorLoss, Flux.params(Microgrid.Brain.policy_net), [(μ_hat,Actions,A)], ADAM(Microgrid.Brain.ηₚ))
    Flux.train!(CriticLoss, Flux.params(Microgrid.Brain.value_net), [(ŷ,y)], ADAM(Microgrid.Brain.ηᵥ))
end

function ChargeOrDischargeBattery!(Microgrid::Microgrid, Action::Float64, bLog::Bool)
    # iConsumptionMismatch = Microgrid.State[1]
    iChargeDischargeVolume = deepcopy(Action)
    if iChargeDischargeVolume >= 0
        iMaxPossibleCharge = min(Microgrid.EnergyStorage.iChargeRate,
            Microgrid.EnergyStorage.iMaxCapacity - Microgrid.EnergyStorage.iCurrentCharge)
        iCharge = min(iMaxPossibleCharge, iChargeDischargeVolume)
        Microgrid.EnergyStorage.iCurrentCharge += iCharge
        ActualAction = iCharge
        if bLog
            println("Actual charge of battery: $iCharge")
        end
    else
        iMaxPossibleDischarge = max(Microgrid.EnergyStorage.iDischargeRate,
            -Microgrid.EnergyStorage.iCurrentCharge)
        iDischarge = max(iMaxPossibleDischarge, iChargeDischargeVolume)
        Microgrid.EnergyStorage.iCurrentCharge += iDischarge
        ActualAction = iDischarge
        if bLog
            println("Actual discharge of battery: $iDischarge")
        end
    end
    # if ActualAction / Action < 0
    #     ActualAction = -ActualAction
    # end
    # t = 3
    return Action, ActualAction
end

function CalculateReward(Microgrid::Microgrid, State::Vector,
    Action::Float64, ActualAction::Float64, iTimeStep::Int64,
    iPenalty::Float64, cPenaltyType::String, bLearn::Bool)
    #iGridVolume = -deepcopy(ActualAction) + State[1] - State[2]
    iGridVolume = -deepcopy(ActualAction) + State[1]
    #dictRewards = GetReward(Microgrid, iTimeStep)
    if iGridVolume >= 0
        #iReward = iGridVolume * dictRewards["iPriceSell"]
        iReward = iGridVolume * Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices.iFirstQuartile[1]
    else
        #iReward = iGridVolume * dictRewards["iPriceBuy"]
        iReward = iGridVolume * Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices.iThirdQuartile[1]
    end
    if (bLearn && abs(Action / ActualAction) > 1)
        if cPenaltyType == "Flat"
            iReward = -iPenalty
        else
            iReward -= iPenalty
        end
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
function Forward(Microgrid::Microgrid, state::Vector, bσFixed::Bool; iσFixed::Float64 = 8.0)
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


function Act!(Microgrid::Microgrid, iTimeStep::Int, iHorizon::Int,
    dictNormParams::Dict, iPenalty::Float64, cPenaltyType::String, bLearn::Bool, bLog::Bool)
    #Random.seed!(72945)
    CurrentState = deepcopy(Microgrid.State)
    Policy, v = Forward(Microgrid, CurrentState, true)
    Action = rand(Policy)
    if bLog
        println("Time step $iTimeStep, intended action $Action kW, prod-cons mismatch ", CurrentState[1])
    end

    #if CurrentState.dictProductionAndConsumption.iProductionConsumptionMismatch >= 0
    Action, ActualAction = ChargeOrDischargeBattery!(Microgrid, Action, bLog)
    iReward = CalculateReward(Microgrid, CurrentState,
        Action, ActualAction, iTimeStep, iPenalty, cPenaltyType, bLearn)

    NextState = GetState(Microgrid, iTimeStep + 1)
    Microgrid.State = NextState
    Microgrid.Reward += iReward
    _, v′ = Forward(Microgrid, NextState, true)
    if iTimeStep + 1 == iHorizon
        bTerminal = true
    else
        bTerminal = false
    end
    Remember!(Microgrid, (CurrentState, Action, ActualAction, iReward, NextState, v, v′, bTerminal))

    if (bLearn && length(Microgrid.Brain.memory) > Microgrid.Brain.min_memory_size)
        Replay!(Microgrid, dictNormParams)
    end

    return bTerminal, iReward

    #return Dict(
    #    "CurrentState" => CurrentState,
    #    "ActualAction" => ActualAction,
    #    "iReward" => iReward,
    #    "NextState" => NextState
    #    )
end

function Run!(Microgrid::Microgrid, iNumberOfEpisodes::Int,
    iTimeStepStart::Int, iTimeStepEnd::Int,
    iPenalty::Float64, cPenaltyType::String, bLearn::Bool, bLog::Bool)
    println("############################")
    println("The run is starting. The parameters are: number of episodes $iNumberOfEpisodes")
    println("Starting time step: $iTimeStepStart")
    println("Ending time step: $iTimeStepEnd")
    println("Penalty height: $iPenalty")
    println("Penalty type: $cPenaltyType")
    println("Learning: $bLearn")
    println("############################")
    Random.seed!(72945)
    cPermittedPenaltyTypes = ["Flat", "Bias"]
    @assert any(cPermittedPenaltyTypes .== cPenaltyType) "The penalty type is wrong"
    iRewards = []
    iRewardsTimeStep = []
    dictParamsForNormalisation = GetParamsForNormalisation(Microgrid)
    restart!(Microgrid,iTimeStepStart)
    for iEpisode in 1:iNumberOfEpisodes
        if bLog
            println("Episode $iEpisode")
        end
        for iTimeStep in iTimeStepStart:1:(iTimeStepEnd-1)
            if bLog
                println("Step $iTimeStep")
            end
            bTerminal, iReward = Act!(Microgrid, iTimeStep, iTimeStepEnd,
                dictParamsForNormalisation, iPenalty, cPenaltyType, bLearn, bLog)
            push!(iRewardsTimeStep, iReward)
            if bTerminal
                push!(iRewards, Microgrid.Reward)
                push!(Microgrid.RewardHistory, Microgrid.Reward)
                restart!(Microgrid,iTimeStepStart)
            end
        end
    end
    println("############################")
    println("The below run has ended: ")
    println("Starting time step: $iTimeStepStart")
    println("Ending time step: $iTimeStepEnd")
    println("Penalty height: $iPenalty")
    println("Penalty type: $cPenaltyType")
    println("Learning: $bLearn")
    println("############################")
    return iRewards, iRewardsTimeStep
end

function RunAll!(params)
    Microgrid, iEpisodes, dRunStart, dRunEnd, iPenalty, cPenaltyType, bLearn, bLog = params
    res = Run!(Microgrid, iEpisodes, dRunStart, dRunEnd, iPenalty, cPenaltyType, bLearn, bLog)
    return Dict(
        (cPenaltyType, iPenalty) => Dict(
                "Microgrid" => Microgrid,
                "result" => res
            )
    )
end

function RunWrapper(DayAheadPricesHandler::DayAheadPricesHandler,
    WeatherDataHandler::WeatherDataHandler, MyWindPark::WindPark,
    MyWarehouse::Warehouse, MyHouseholds::⌂,
    iEpisodes::Int, dRunStartTrain::Int, dRunEndTrain::Int,
    dRunStartTest::Int, dRunEndTest::Int,
    Penalties::Vector, PenaltyTypes::Vector;
    bTestMode::Bool = false)

    FinalDict = Dict{}()
    for pen in 1:length(Penalties), type in 1:length(PenaltyTypes)
        MyMicrogrid = GetMicrogrid(DayAheadPricesHandler, WeatherDataHandler,
            MyWindPark, MyWarehouse, MyHouseholds)
        if bTestMode
            MyMicrogrid.Brain.min_memory_size = 8
            MyMicrogrid.Brain.batch_size = 5
        end

        TrainRun = Run!(MyMicrogrid, iEpisodes, dRunStartTrain, dRunEndTrain, Penalties[pen], PenaltyTypes[type], true)
        iTrainRewardHistory = TrainRun[1]
        iTrainIntendedActions = deepcopy([MyMicrogrid.Brain.memory[i][2] for i in 1:length(MyMicrogrid.Brain.memory)])
        iTrainActualActions = deepcopy([MyMicrogrid.Brain.memory[i][3] for i in 1:length(MyMicrogrid.Brain.memory)])
        iTrainMismatch = deepcopy([MyMicrogrid.Brain.memory[i][1][1] for i in 1:length(MyMicrogrid.Brain.memory)])
        iTrainBatteryCharge = deepcopy([MyMicrogrid.Brain.memory[i][1][3] for i in 1:length(FullMicrogrid.Brain.memory)])

        MyMicrogrid.Brain.memory = []
        MyMicrogrid.EnergyStorage.iCurrentCharge = 0

        TestRun = Run!(MyMicrogrid, iEpisodes, dRunStartTest, dRunEndTest, Penalties[pen], PenaltyTypes[type], false)
        iTestRewardHistory = TestRun[1]
        iTestIntendedActions = deepcopy([MyMicrogrid.Brain.memory[i][2] for i in 1:length(MyMicrogrid.Brain.memory)])
        iTestActualActions = deepcopy([MyMicrogrid.Brain.memory[i][3] for i in 1:length(MyMicrogrid.Brain.memory)])
        iTestMismatch = deepcopy([MyMicrogrid.Brain.memory[i][1][1] for i in 1:length(MyMicrogrid.Brain.memory)])
        iTestBatteryCharge = deepcopy([MyMicrogrid.Brain.memory[i][1][3] for i in 1:length(FullMicrogrid.Brain.memory)])

        push!(FinalDict, (Penalties[pen], PenaltyTypes[type]) => Dict(
                "Microgrid" => MyMicrogrid,
                "iTrainRewardHistory" => iTrainRewardHistory,
                "iTrainIntendedActions" => iTrainIntendedActions,
                "iTrainActualActions" => iTrainActualActions,
                "iTrainMismatch" => iTrainMismatch,
                "iTrainBatteryCharge" => iTrainBatteryCharge,
                "iTestRewardHistory" => iTestRewardHistory,
                "iTestIntendedActions" => iTestIntendedActions,
                "iTestActualActions" => iTestActualActions,
                "iTestMismatch" => iTestMismatch,
                "iTestBatteryCharge" => iTestBatteryCharge

            )
        )
    end
    return FinalDict
end
