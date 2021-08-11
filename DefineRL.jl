using Distributions, Dates, DataFrames
using Flux, Pipe

function GetState(Microgrid::Microgrid, iLookBack::Int, iTimeStep::Int)
    iTotalProduction = Microgrid.dfTotalProduction.TotalProduction[iTimeStep:iTimeStep+iLookBack]
    iTotalConsumption = Microgrid.dfTotalConsumption.TotalConsumption[iTimeStep:iTimeStep+iLookBack]
    iProductionConsumptionMismatch = iTotalProduction .- iTotalConsumption
    # iDayAheadPrices = Microgrid.DayAheadPricesHandler.dfDayAheadPrices.Price[iTimeStep-iLookBack:iTimeStep]

    Microgrid.State = [
        iProductionConsumptionMismatch
        Microgrid.EnergyStorage.iCurrentCharge
    ]
end

function GetParamsForNormalisation(Microgrid::Microgrid)
    iOverallConsMismatch = Microgrid.dfTotalProduction.TotalProduction - Microgrid.dfTotalConsumption.TotalConsumption
    # iOverallPriceLevels = Microgrid.DayAheadPricesHandler.dfDayAheadPrices.Price
    return Dict(
    #    "ProductionScalingParams" => extrema(Microgrid.dfTotalProduction.TotalProduction),
    #    "ConsumptionScalingParams" => extrema(Microgrid.dfTotalConsumption.TotalConsumption),
        "ConsMismatchParams" => extrema(iOverallConsMismatch),
        # "PriceParams" => extrema(iOverallPriceLevels),
        "ChargeParams" => (0, Microgrid.EnergyStorage.iMaxCapacity)
    )
end

function NormaliseState!(State::Vector, Params::Dict, iLookBack::Int)
    #(iProdMin, iProdMax) = Params["ProductionScalingParams"]
    #(iConsMin, iConsMax) = Params["ConsumptionScalingParams"]
    (iMismatchMin, iMismatchMax) = Params["ConsMismatchParams"]
    # (iPriceMin, iPriceMax) = Params["PriceParams"]
    (iChargeMin, iChargeMax) = Params["ChargeParams"]
    for i in 1:1:(iLookBack+1)
        State[i] = (State[i] - iMismatchMin) / (iMismatchMax - iMismatchMin)
    end
    #for i in (iLookBack+2):1:(2*(iLookBack+1))
    #    State[i] = (State[i] - iPriceMin) / (iPriceMax - iPriceMin)
    #end
    # State[length(State)] = (State[length(State)] - iChargeMin) / (iChargeMax - iChargeMin)
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

function ActorLoss(x, Actions, A; ι::Float64 = 0.001)
    #println("μ_policy: $μ_policy")
    #println(typeof(μ_policy))
    μ_hat, σ_hat = MyMicrogrid.Brain.policy_net(x)
    σ_hat = softplus(σ_hat) + 1e-1
    # μ_hat = MyMicrogrid.Brain.policy_net(x)
    #MyMicrogrid.Brain.cPolicyOutputLayerType == "sigmoid" ? σ_hat = 0.01 : σ_hat = 1.0
    Policy = Distributions.Normal.(μ_hat, σ_hat)
    #println("Policy: $Policy")
    iScoreFunction = -Distributions.logpdf.(Policy, Actions)
    #println("iScoreFunction: $iScoreFunction")
    iLoss = sum(iScoreFunction .* A) / size(A,1)
    iEntropy = sum(Distributions.entropy.(Policy))
    println("Actor loss function: $iLoss")
    return iLoss - ι*iEntropy
    # return iLoss
end

function CriticLoss(x, y; ξ = 0.5)
    return ξ*Flux.mse(MyMicrogrid.Brain.value_net(x), y)
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
        if bTerminal
            R = Reward
        else
            R = Reward + Microgrid.Brain.β * v′
        end
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
    #println("Actor parameters: ", Flux.params(Microgrid.Brain.policy_net))
    #println("Actor parameters: ", Flux.params(Microgrid.Brain.policy_net)[1][1:3])
    #println("Critic parameters: ", Flux.params(Microgrid.Brain.value_net)[1][1:3])
end

function ChargeOrDischargeBattery!(Microgrid::Microgrid, Action::Float64, iLookBack::Int, bLog::Bool)
    iConsumptionMismatch = Microgrid.State[1]
    #if Microgrid.Brain.cPolicyOutputLayerType == "sigmoid"
    #     iChargeDischargeVolume = deepcopy(Action) * iConsumptionMismatch
    #else
    #    iChargeDischargeVolume = deepcopy(Action)
    #end
    iChargeDischargeVolume = deepcopy(Action) * iConsumptionMismatch
    # iChargeDischargeVolume = deepcopy(Action)
    if iChargeDischargeVolume >= 0
        iMaxPossibleCharge = min(Microgrid.EnergyStorage.iChargeRate,
            Microgrid.EnergyStorage.iMaxCapacity - Microgrid.EnergyStorage.iCurrentCharge * Microgrid.EnergyStorage.iMaxCapacity)
        iCharge = min(iMaxPossibleCharge, iChargeDischargeVolume)
        Microgrid.EnergyStorage.iCurrentCharge += iCharge / Microgrid.EnergyStorage.iMaxCapacity
        #if Microgrid.Brain.cPolicyOutputLayerType == "sigmoid"
        #    ActualAction = iCharge / iConsumptionMismatch
        #else
        #    ActualAction = iCharge
        #end
        ActualAction = iCharge / iConsumptionMismatch
        # ActualAction = iCharge
        if bLog
            println("Actual charge of battery: $iCharge")
        end
    else
        iMaxPossibleDischarge = max(Microgrid.EnergyStorage.iDischargeRate,
            -Microgrid.EnergyStorage.iCurrentCharge * Microgrid.EnergyStorage.iMaxCapacity)
        iDischarge = max(iMaxPossibleDischarge, iChargeDischargeVolume)
        Microgrid.EnergyStorage.iCurrentCharge += iDischarge / Microgrid.EnergyStorage.iMaxCapacity
        #if Microgrid.Brain.cPolicyOutputLayerType == "sigmoid"
        #    ActualAction = iDischarge / iConsumptionMismatch
        #else
        #    ActualAction = iDischarge
        #end
        ActualAction = iDischarge / iConsumptionMismatch
        # ActualAction = iDischarge
        if bLog
            println("Actual discharge of battery: $iDischarge")
        end
    end
    return Action, ActualAction
end

function CalculateReward(Microgrid::Microgrid, State::Vector, iLookBack::Int,
    Action::Float64, ActualAction::Float64, iTimeStep::Int, bLearn::Bool)
    #if Microgrid.Brain.cPolicyOutputLayerType == "sigmoid"
    #    iMicrogridVolume = deepcopy(ActualAction) * State[iLookBack+1]
    #else
    #    iMicrogridVolume = deepcopy(ActualAction)
    #end
    iMicrogridVolume = deepcopy(ActualAction) * State[1]
    # iMicrogridVolume = deepcopy(ActualAction)
    iGridVolume = State[1] - iMicrogridVolume
    # iGridPrice = Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices.iMedian[1]
    # iReward = iGridVolume * iGridPrice
    #dictRewards = GetReward(Microgrid, iTimeStep)
    if iGridVolume >= 0
        #iReward = iGridVolume * dictRewards["iPriceSell"]
        iReward = iGridVolume * Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices.i45Quantile[1]
    else
        #iReward = iGridVolume * dictRewards["iPriceBuy"]
        iReward = iGridVolume * Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices.i55Quantile[1]
    end

    if iMicrogridVolume >= 0
        iMicrogridReward = iMicrogridVolume * Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices.i45Quantile[1]
    else
        iMicrogridReward = iMicrogridVolume * Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices.i55Quantile[1]
    end
    iMicrogridReward = 0

    return (iReward + iMicrogridReward) * 0.001 # the reward is rescaled as per Ji et al
end

# update pamieci
function Remember!(Microgrid::Microgrid, step::Tuple)
    length(Microgrid.Brain.memory) == Microgrid.Brain.memory_size && deleteat!(Microgrid.Brain.memory,1)
    push!(Microgrid.Brain.memory, step)
end

# definicja, ktore kroki mamy wykonac
# bierze siec neuronowa i zwraca jej wynik
function Forward(Microgrid::Microgrid, state::Vector, bσFixed::Bool, dictNormParams::Dict, iLookBack::Int)
    # StateForLearning = deepcopy(Microgrid.State)
    StateForLearning = @pipe deepcopy(Microgrid.State) |> NormaliseState!(_, dictNormParams, iLookBack)
    # μ_hat = Microgrid.Brain.policy_net(StateForLearning)[1]    # wektor p-w na bazie sieci aktora
    # MyMicrogrid.Brain.cPolicyOutputLayerType == "sigmoid" ? σ_hat  = 0.01 : σ_hat  = 1.0
    μ_hat, σ_hat = MyMicrogrid.Brain.policy_net(StateForLearning)
    σ_hat = softplus(σ_hat) + 1e-1
    Policy = Distributions.Normal(μ_hat, σ_hat)
    #MyMicrogrid.Brain.cPolicyOutputLayerType == "sigmoid" ? iσFixed = 0.01 : iσFixed = 1.0
    #if bσFixed
    #    Policy = Distributions.Normal(μ_policy, iσFixed)
    #else
    #    println("Not yet implemented")
    #    return nothing
    #end
    v = Microgrid.Brain.value_net(StateForLearning)[1]   # wektor f wartosic na bazie sieci krytyka
    return Policy,v
end


function Act!(Microgrid::Microgrid, iTimeStep::Int, iHorizon::Int, iLookBack::Int,
    dictNormParams::Dict, bLearn::Bool, bLog::Bool)
    #Random.seed!(72945)
    CurrentState = deepcopy(Microgrid.State)
    Policy, v = Forward(Microgrid, CurrentState, true, dictNormParams, iLookBack)
    Action = rand(Policy)
    ActionForPrint = Action * 100
    if bLog
        # println("Time step $iTimeStep, intended action $Action kW, prod-cons mismatch ", CurrentState[iLookBack+1])
        println("Time step $iTimeStep, intended action $ActionForPrint % of mismatch, prod-cons mismatch ", CurrentState[1])
        #if Microgrid.Brain.cPolicyOutputLayerType == "sigmoid"
        #    println("Time step $iTimeStep, intended action $ActionForPrint % of mismatch, prod-cons mismatch ", CurrentState[iLookBack+1])
        #else
        #    println("Time step $iTimeStep, intended action $Action kW, prod-cons mismatch ", CurrentState[iLookBack+1])
        #end
    end

    Action, ActualAction = ChargeOrDischargeBattery!(Microgrid, Action, iLookBack, bLog)
    iReward = CalculateReward(Microgrid, CurrentState, iLookBack,
        Action, ActualAction, iTimeStep, bLearn)

    NextState = GetState(Microgrid, iLookBack, iTimeStep + 1)
    Microgrid.State = NextState
    Microgrid.Reward += iReward
    _, v′ = Forward(Microgrid, NextState, true, dictNormParams, iLookBack)
    if iTimeStep + 1 == iHorizon
        bTerminal = true
    else
        bTerminal = false
    end
    Remember!(Microgrid, (CurrentState, Action, ActualAction, iReward, NextState, v, v′, bTerminal))

    if (bLearn && length(Microgrid.Brain.memory) > Microgrid.Brain.min_memory_size)
        Replay!(Microgrid, dictNormParams, iLookBack)
    end

    return bTerminal, iReward

end

function Run!(Microgrid::Microgrid, iNumberOfEpisodes::Int, iLookBack::Int,
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
        if bLog
            println("Episode $iEpisode")
        end
        for iTimeStep in iTimeStepStart:1:(iTimeStepEnd-1)
            if bLog
                println("Step $iTimeStep")
            end
            bTerminal, iReward = Act!(Microgrid, iTimeStep, iTimeStepEnd, iLookBack,
                dictParamsForNormalisation, bLearn, bLog)
            push!(iRewardsTimeStep, iReward)
            if bTerminal
                push!(iRewards, Microgrid.Reward)
                push!(Microgrid.RewardHistory, Microgrid.Reward)
                restart!(Microgrid,iLookBack,iTimeStepStart)
            end
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
