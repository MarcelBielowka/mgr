using Distributions, Dates, DataFrames
using Flux, Pipe

function GetState(Microgrid::Microgrid, iLookBack::Int, iTimeStep::Int)
    iTotalProduction = Microgrid.dfTotalProduction.TotalProduction[iTimeStep:iTimeStep+iLookBack]
    iTotalConsumption = Microgrid.dfTotalConsumption.TotalConsumption[iTimeStep:iTimeStep+iLookBack]
    iProductionConsumptionMismatch = iTotalProduction .- iTotalConsumption
    iDayAheadPrices = Microgrid.DayAheadPricesHandler.dfDayAheadPrices.TransformedPrice[iTimeStep:iTimeStep+iLookBack]

    Microgrid.State = [
        iProductionConsumptionMismatch
        iDayAheadPrices
        Microgrid.EnergyStorage.iCurrentCharge
    ]
end

function GetParamsForNormalisation(Microgrid::Microgrid)
    iOverallConsMismatch = Microgrid.dfTotalProduction.TotalProduction - Microgrid.dfTotalConsumption.TotalConsumption
    return Dict(
        "ConsMismatchParams" => extrema(iOverallConsMismatch),
        "ChargeParams" => (0, Microgrid.EnergyStorage.iMaxCapacity)
    )
end

function NormaliseState!(State::Vector, Params::Dict, iLookBack::Int)
    (iMismatchMin, iMismatchMax) = Params["ConsMismatchParams"]
    (iChargeMin, iChargeMax) = Params["ChargeParams"]
    for i in 1:1:(iLookBack+1)
        State[i] = (State[i] - iMismatchMin) / (iMismatchMax - iMismatchMin)
    end
    return State
end

function restart!(Microgrid::Microgrid, iLookBack::Int, iInitTimeStep::Int)
    Microgrid.Reward = 0
    Microgrid.EnergyStorage.iCurrentCharge = 0
    GetState(Microgrid, iLookBack, iInitTimeStep)
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

# x - Score function
# y - Advantage function
function ActorLoss(x, y; ι::Float64 = 0.001)
    iLoss = sum(x .* y)
    println("Actor loss function: ", iLoss)
    return iLoss
end

function CriticLoss(ŷ, y; ξ = 0.5)
    iCriticLoss = ξ*Flux.mse(ŷ, y)
    println("Critic loss: $iCriticLoss")
    return iCriticLoss
end

function Replay!(Microgrid::Microgrid, dictNormParams::Dict, iLookBack::Int)
    # println("Start learning")
    x = zeros(Float64, length(Microgrid.State), Microgrid.Brain.batch_size)
    Actions = zeros(Float64, 1, Microgrid.Brain.batch_size)
    A = zeros(Float64, 1, Microgrid.Brain.batch_size)
    y = zeros(Float64, 1, Microgrid.Brain.batch_size)
    iter = @pipe sample(Microgrid.Brain.memory, Microgrid.Brain.batch_size, replace = false) |>
        enumerate |> collect
    for (i, step) in iter
        State, Action, ActualAction, Reward, NextState, v, v′, bTerminal = step
        #if bTerminal
        #    R = Reward
        #else
        #    R = Reward + Microgrid.Brain.β * v′
        #end
        R = Reward + Microgrid.Brain.β * v′
        iAdvantage = R - v
        # StateForLearning = deepcopy(State)
        StateForLearning = @pipe deepcopy(State) |> NormaliseState!(_, dictNormParams, iLookBack)
        x[:, i] .= StateForLearning
        A[:, i] .= iAdvantage
        Actions[:,i] .= Action
        y[:, i] .= R
    end

    Flux.train!(ActorLoss, Flux.params(Microgrid.Brain.policy_net), [(x,Actions,A)], ADAM(Microgrid.Brain.ηₚ))
    Flux.train!(CriticLoss, Flux.params(Microgrid.Brain.value_net), [(x,y)], ADAM(Microgrid.Brain.ηᵥ))
end

function Learn!(Microgrid::Microgrid, step::Tuple, dictNormParams::Dict, iLookBack::Int)
    State, Action, ActualAction, Reward, NextState, v, v′, bTerminal = step

    # calculate basic metrics
    R = Reward + Microgrid.Brain.β * v′ #TD target
    StateForLearning = @pipe deepcopy(State) |> NormaliseState!(_, dictNormParams, iLookBack) # in usual circumstances that's StateForLearning
    A = R - v                               # TD error
    y = R

    # train
    # Actor learns based on TD error
    Flux.train!(
        (x, Action, A) -> ActorLoss(
            (@pipe Distributions.Normal.(Microgrid.Brain.policy_net(StateForLearning), 0.1) |> -Distributions.logpdf.(_, Action)), A
        ),
        Flux.params(Microgrid.Brain.policy_net),
        [(StateForLearning, Action, A)],
        ADAM(Microgrid.Brain.ηₚ)
    )

    # Critic learns based on TD target
    Flux.train!(
        (x,y) -> CriticLoss(Microgrid.Brain.value_net(StateForLearning), y),
        Flux.params(Microgrid.Brain.value_net),
        [(StateForLearning,y)],
        ADAM(Microgrid.Brain.ηᵥ)
    )
end

function ChargeOrDischargeBattery!(Microgrid::Microgrid, Action::Float64, iLookBack::Int, bLog::Bool)
    iConsumptionMismatch = Microgrid.State[1]
    iChargeDischargeVolume = deepcopy(Action) * iConsumptionMismatch
    if iChargeDischargeVolume >= 0
        iMaxPossibleCharge = min(Microgrid.EnergyStorage.iChargeRate,
            Microgrid.EnergyStorage.iMaxCapacity - Microgrid.EnergyStorage.iCurrentCharge * Microgrid.EnergyStorage.iMaxCapacity)
        iCharge = min(iMaxPossibleCharge, iChargeDischargeVolume)
        iChargeNormalised = iCharge / Microgrid.EnergyStorage.iMaxCapacity
        Microgrid.EnergyStorage.iCurrentCharge += iChargeNormalised
        ActualAction = iCharge / iConsumptionMismatch
        if bLog
            println("Actual charge of battery: ", round(iCharge; digits = 2))
        end
    else
        iMaxPossibleDischarge = max(Microgrid.EnergyStorage.iDischargeRate,
            -Microgrid.EnergyStorage.iCurrentCharge * Microgrid.EnergyStorage.iMaxCapacity)
        iDischarge = max(iMaxPossibleDischarge, iChargeDischargeVolume)
        iDischargeNormalised = iDischarge / Microgrid.EnergyStorage.iMaxCapacity
        Microgrid.EnergyStorage.iCurrentCharge += iDischargeNormalised
        ActualAction = iDischarge / iConsumptionMismatch
        if bLog
            println("Actual discharge of battery: ", round(iDischarge; digits = 2))
        end
    end
    return Action, ActualAction
end

function CalculateReward(Microgrid::Microgrid, State::Vector, iLookBack::Int,
    Action::Float64, ActualAction::Float64, iGridLongVolumeCoefficient::Float64,
    iTimeStep::Int, bLearn::Bool)
    iMicrogridVolume = State[1] * ActualAction
    iGridVolume = State[1] - iMicrogridVolume
    iGridShortVolumeCoefficient = 2 - iGridLongVolumeCoefficient
    if iGridVolume >= 0
       iReward = iGridVolume * Microgrid.DayAheadPricesHandler.dfDayAheadPrices.Price[iTimeStep] * iGridLongVolumeCoefficient
    else
        iReward = iGridVolume * Microgrid.DayAheadPricesHandler.dfDayAheadPrices.Price[iTimeStep] * iGridShortVolumeCoefficient
    end

    if iMicrogridVolume >= 0
        iMicrogridReward = iMicrogridVolume * Microgrid.DayAheadPricesHandler.dfDayAheadPrices.Price[iTimeStep]
    else
        iMicrogridReward = iMicrogridVolume * Microgrid.DayAheadPricesHandler.dfDayAheadPrices.Price[iTimeStep]
    end

    return (iReward + iMicrogridReward) * 0.001
end

# update pamieci
function Remember!(Microgrid::Microgrid, step::Tuple)
    length(Microgrid.Brain.memory) == Microgrid.Brain.memory_size && deleteat!(Microgrid.Brain.memory,1)
    push!(Microgrid.Brain.memory, step)
end#

# definicja, ktore kroki mamy wykonac
# bierze siec neuronowa i zwraca jej wynik
function Forward(Microgrid::Microgrid, state::Vector, bσFixed::Bool, dictNormParams::Dict, iLookBack::Int,
        bPrintPolicyParams::Bool)
    # StateForLearning = deepcopy(Microgrid.State)
    StateForLearning = @pipe deepcopy(Microgrid.State) |> NormaliseState!(_, dictNormParams, iLookBack)
    μ_hat = Microgrid.Brain.policy_net(StateForLearning)    # wektor p-w na bazie sieci aktora
    σ_hat = 0.1
    if bPrintPolicyParams
        println("Policy params: $μ_hat, $σ_hat")
    end
    Policy = Distributions.Normal.(μ_hat, σ_hat)
    v = Microgrid.Brain.value_net(StateForLearning)[1]   # wektor f wartosic na bazie sieci krytyka
    return Policy[1],v
end


function Act!(Microgrid::Microgrid, iTimeStep::Int, iHorizon::Int, iLookBack::Int,
    iGridLongVolumeCoefficient::Float64,
    dictNormParams::Dict, bLearn::Bool, bLog::Bool)
    #Random.seed!(72945)
    CurrentState = deepcopy(Microgrid.State)
    Policy, v = Forward(Microgrid, CurrentState, true, dictNormParams, iLookBack, true)
    Action = rand(Policy)
    ActionForPrint = round(Action * 100; digits = 2)
    if bLog
        println("Currently free storage capacity: ", Microgrid.State[length(Microgrid.State)] * Microgrid.EnergyStorage.iMaxCapacity)
        println("Intended action $ActionForPrint % of storage capacity")
        println("Current prod-cons mismatch ", round(CurrentState[1]; digits = 2))
    end

    Action, ActualAction = ChargeOrDischargeBattery!(Microgrid, Action, iLookBack, bLog)
    iReward = CalculateReward(Microgrid, CurrentState, iLookBack,
        Action, ActualAction, iGridLongVolumeCoefficient, iTimeStep, bLearn)

    NextState = GetState(Microgrid, iLookBack, iTimeStep + 1)
    Microgrid.State = NextState
    Microgrid.Reward += iReward
    _, v′ = Forward(Microgrid, NextState, true, dictNormParams, iLookBack, false)
    if iTimeStep + 1 == iHorizon
        bTerminal = true
    else
        bTerminal = false
    end
    step = (deepcopy(CurrentState), deepcopy(Action), deepcopy(ActualAction),
        deepcopy(iReward), deepcopy(NextState), deepcopy(v), deepcopy(v′), deepcopy(bTerminal))
    Remember!(Microgrid, step)

    if bLearn
        Learn!(Microgrid, step, dictNormParams, iLookBack)
    end

    return bTerminal, iReward
end

function Run!(Microgrid::Microgrid, iNumberOfEpisodes::Int, iLookBack::Int,
    iGridLongVolumeCoefficient::Float64,
    iTimeStepStart::Int, iTimeStepEnd::Int, bLearn::Bool, bLog::Bool)
    println("############################")
    println("The run is starting. The parameters are:")
    println("Number of episodes $iNumberOfEpisodes")
    println("Look ahead steps: $iLookBack")
    println("Starting time step: $iTimeStepStart")
    println("Ending time step: $iTimeStepEnd")
    println("Learning: $bLearn")
    println("MG's brain type: ", Microgrid.Brain.cPolicyOutputLayerType)
    println("############################")
    Random.seed!(72945)
    iRewards = []
    iRewardsTimeStep = []
    dictParamsForNormalisation = GetParamsForNormalisation(Microgrid)
    restart!(Microgrid,iLookBack,iTimeStepStart)
    for iEpisode in 1:iNumberOfEpisodes
        TestState = @pipe deepcopy(Microgrid.State) |> NormaliseState!(_, dictParamsForNormalisation, iLookBack)
        TestValue = abs(Microgrid.Brain.policy_net(TestState)[1])
        println("TestState: $TestState")
        println("TestValue: $TestValue")
        if TestValue < 100
            if bLog
                println("Episode $iEpisode")
            end
            for iTimeStep in iTimeStepStart:1:(iTimeStepEnd-1)
                if bLog
                    println("\nStep $iTimeStep")
                end
                bTerminal, iReward = Act!(Microgrid, iTimeStep, iTimeStepEnd, iLookBack,
                    iGridLongVolumeCoefficient,
                    dictParamsForNormalisation, bLearn, bLog)
                push!(iRewardsTimeStep, iReward)
                if bTerminal
                    push!(iRewards, Microgrid.Reward)
                    push!(Microgrid.RewardHistory, Microgrid.Reward)
                    restart!(Microgrid,iLookBack,iTimeStepStart)
                end
            end
        else
            println("Mean of policy distribution exceeded 100. Learning is stopped after episode $iEpisode")
            iEpisode = iNumberOfEpisodes
        end
    end
    println("############################")
    println("The below run has ended: ")
    println("Number of episodes $iNumberOfEpisodes")
    println("Look ahead steps: $iLookBack")
    println("Starting time step: $iTimeStepStart")
    println("Ending time step: $iTimeStepEnd")
    println("Learning: $bLearn")
    println("MG's brain type: ", Microgrid.Brain.cPolicyOutputLayerType)
    println("############################")
    return iRewards, iRewardsTimeStep
end

function RunAll!(params)
    Microgrid, iEpisodes, dRunStart, dRunEnd, bLearn, bLog = params
    res = Run!(Microgrid, iEpisodes, dRunStart, dRunEnd, bLearn, bLog)
    return Dict(
        "Microgrid" => Microgrid,
        "result" => res
    )
end

function RunWrapper(DayAheadPricesHandler::DayAheadPricesHandler,
    WeatherDataHandler::WeatherDataHandler, MyWindPark::WindPark,
    MyWarehouse::Warehouse, MyHouseholds::⌂, cPolicyOutputLayerTypes::Vector{String},
    iEpisodes::Int, dRunStartTrain::Int, dRunEndTrain::Int,
    dRunStartTest::Int, dRunEndTest::Int, iLookBacks::Vector, bLog::Bool;
    bTestMode::Bool = false)

    @assert (["identity", "sigmoid"] == cPolicyOutputLayerTypes) "The policy output layer type is not correct"
    FinalDict = Dict{}()
    for cPolicyOutputLayerType in cPolicyOutputLayerTypes, iLookBack in iLookBacks
        println(iLookBack)
        MyMicrogrid = GetMicrogrid(DayAheadPricesHandler, WeatherDataHandler,
            MyWindPark, MyWarehouse, MyHouseholds,
            cPolicyOutputLayerType, iLookBack)
        if bTestMode
            MyMicrogrid.Brain.min_memory_size = 8
            MyMicrogrid.Brain.batch_size = 5
        end

        TrainRun = Run!(MyMicrogrid, iEpisodes, iLookBack, dRunStartTrain, dRunEndTrain, true, bLog)
        iTrainRewardHistory = TrainRun[1]
        iTrainIntendedActions = deepcopy([MyMicrogrid.Brain.memory[i][2] for i in 1:length(MyMicrogrid.Brain.memory)])
        iTrainActualActions = deepcopy([MyMicrogrid.Brain.memory[i][3] for i in 1:length(MyMicrogrid.Brain.memory)])
        iTrainMismatch = deepcopy([MyMicrogrid.Brain.memory[i][1][1] for i in 1:length(MyMicrogrid.Brain.memory)])
        iTrainBatteryCharge = deepcopy([MyMicrogrid.Brain.memory[i][1][length(MyMicrogrid.State)] for i in 1:length(MyMicrogrid.Brain.memory)])

        MicrogridAfterTraining = deepcopy(MyMicrogrid)
        MyMicrogrid.Brain.memory = []
        MyMicrogrid.EnergyStorage.iCurrentCharge = 0

        TestRun = Run!(MyMicrogrid, iEpisodes, iLookBack, dRunStartTest, dRunEndTest, false, bLog)
        iTestRewardHistory = TestRun[1]
        iTestIntendedActions = deepcopy([MyMicrogrid.Brain.memory[i][2] for i in 1:length(MyMicrogrid.Brain.memory)])
        iTestActualActions = deepcopy([MyMicrogrid.Brain.memory[i][3] for i in 1:length(MyMicrogrid.Brain.memory)])
        iTestMismatch = deepcopy([MyMicrogrid.Brain.memory[i][1][1] for i in 1:length(MyMicrogrid.Brain.memory)])
        iTestBatteryCharge = deepcopy([MyMicrogrid.Brain.memory[i][1][length(MyMicrogrid.State)] for i in 1:length(MyMicrogrid.Brain.memory)])

        push!(FinalDict, (cPolicyOutputLayerType, iLookBack) => Dict(
                "MicrogridAfterTraining" => MicrogridAfterTraining,
                "Microgrid" => deepcopy(MyMicrogrid),
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

function FineTuneTheMicrogrid(DayAheadPricesHandler::DayAheadPricesHandler,
    WeatherDataHandler::WeatherDataHandler, MyWindPark::WindPark,
    MyWarehouse::Warehouse, MyHouseholds::⌂,
    cPolicyOutputLayerType::Vector{String}, iEpisodes::Vector{Int},
    dRunStartTrain::Int, dRunEndTrain::Int,
    dRunStartTest::Int, dRunEndTest::Int,
    iLookBack::Vector{Int}, iGridLongVolumeCoefficient::Vector{Float64},
    iβ::Vector{Float64},
    iActorLearningRate::Vector{Float64}, iCriticLearningRate::Vector{Float64},
    iHiddenLayerNeuronsActor::Vector{Int}, iHiddenLayerNeuronsCritic::Vector{Int})

    ### Some input validation ###
    if any(iEpisodes .< 0)
        println("Number of episodes cannot be lower than 10")
        return nothing
    end

    if any(iLookBack .< 0)
        println("Number of look backs cannot be lower than 0")
        return nothing
    end

    if (any(iGridLongVolumeCoefficient .< 0) || any(iGridLongVolumeCoefficient .> 2))
        println("Grid long volume coefficient must be within 0 and 2, preferably within 0 and 1")
        return nothing
    end

    if (any(iHiddenLayerNeuronsActor .< 10) || any(iHiddenLayerNeuronsCritic .< 10))
        println("Hidden layers must have more than 10 neurons")
        return nothing
    end

    if any((iHiddenLayerNeuronsCritic .% 2) .!= 0)
        println("The number of hidden layers of the critic must be dividable by 2")
        return nothing
    end

    if (any(iActorLearningRate .< 0) || any(iCriticLearningRate .< 0))
        println("Leargning rates can't be negative")
        return nothing
    end

    if (any(iActorLearningRate .> 0.5) || any(iCriticLearningRate .> 0.5))
        println("Leargning rates can't exceed 0.5")
        return nothing
    end

    AllTheResults = Vector{ResultsHolder}()

    for cCurrentPolicyOutputLayerType in cPolicyOutputLayerType,
        iCurrentEpisodeLength in iEpisodes,
        iCurrentLookBack in iLookBack,
        iCurrentβ in iβ,
        iCurrentGridCoefficient in iGridLongVolumeCoefficient,
        iCurrentActorLearningRate in iActorLearningRate,
        iCurrentCriticLearningRate in iCriticLearningRate,
        iCurrentHiddenLayerNeuronsActor in iHiddenLayerNeuronsActor,
        iCurrentHiddenLayerNeuronsCritic in iHiddenLayerNeuronsCritic

        CurrentResult = GetResultsHolder(
            DayAheadPricesHandler,
            WeatherDataHandler,
            MyWindPark,
            MyWarehouse,
            MyHouseholds,
            cCurrentPolicyOutputLayerType,
            iCurrentEpisodeLength,
            dRunStartTrain,
            dRunEndTrain,
            dRunStartTest,
            dRunEndTest,
            iCurrentLookBack,
            iCurrentGridCoefficient,
            iCurrentβ,
            iCurrentActorLearningRate,
            iCurrentCriticLearningRate,
            iCurrentHiddenLayerNeuronsActor,
            iCurrentHiddenLayerNeuronsCritic
        )
    push!(AllTheResults, CurrentResult)

    end

    return AllTheResults
end

function FineTuneMembers(DayAheadPricesHandler::DayAheadPricesHandler,
    WeatherDataHandler::WeatherDataHandler,
    iTurbineMaxCapacity::Float64, iTurbineRatedSpeed::Float64,
    iTurbineCutinSpeed::Float64, iTurbineCutoffSpeed::Float64,
    iNumberOfTurbines::Vector{Int},
    dfWarehouseEnergyConsumption::DataFrame, dfConsignmentHistory::DataFrame,
    iNumberOfWarehouses::Int, iYear::Int,
    iHeatCoefficient::Float64, iInsideTemp::Float64,
    iPVMaxCapacity::Float64, iPVγ_temp::Float64,
    iNoct::Int, iNumberOfPanels::Vector{Int},
    iStorageMaxCapacity::Float64, iStorageChargeRate::Float64,
    iStorageDischargeRate::Float64, iNumberOfStorageCells::Vector{Int},
    MyHouseholds::⌂,
    cPolicyOutputLayerType::Vector{String}, iEpisodes::Vector{Int},
    dRunStartTrain::Int, dRunEndTrain::Int,
    dRunStartTest::Int, dRunEndTest::Int,
    iLookBack::Vector{Int}, iGridLongVolumeCoefficient::Vector{Float64},
    iβ::Vector{Float64},
    iActorLearningRate::Vector{Float64}, iCriticLearningRate::Vector{Float64},
    iHiddenLayerNeuronsActor::Vector{Int}, iHiddenLayerNeuronsCritic::Vector{Int})

    AllTheResults = Vector{MembersResultsHolder}()

    for iCurrentTurbines in iNumberOfTurbines, iCurrentPanels in iNumberOfPanels, iCurrentCells in iNumberOfStorageCells
        CurrentWindPark = GetWindPark(iTurbineMaxCapacity, iTurbineRatedSpeed,
            iTurbineCutinSpeed, iTurbineCutoffSpeed, Weather, iCurrentTurbines)
        CurrentWarehouse = GetTestWarehouse(dfRawEnergyConsumption, dfRawConsHistory,
            iNumberOfWarehouses, iYear, iHeatCoefficient, iInsideTemp,
            iPVMaxCapacity, iPVγ_temp, iNoct,
            iCurrentPanels, Weather,
            iStorageMaxCapacity, iStorageChargeRate, iStorageDischargeRate, iCurrentCells)

        Result = FineTuneTheMicrogrid(DayAheadPricesHandler,
            WeatherDataHandler, CurrentWindPark,
            CurrentWarehouse, MyHouseholds,
            cPolicyOutputLayerType, iEpisodes,
            dRunStartTrain, dRunEndTrain,
            dRunStartTest, dRunEndTest,
            iLookBack, iGridLongVolumeCoefficient,
            iβ,
            iActorLearningRate, iCriticLearningRate,
            iHiddenLayerNeuronsActor, iHiddenLayerNeuronsCritic)

        CurrentResult = GetMembersResultsHolder(
            iCurrentTurbines,
            iCurrentPanels,
            iCurrentCells,
            Result
        )

        push!(AllTheResults, CurrentResult)
    end
    return AllTheResults
end
