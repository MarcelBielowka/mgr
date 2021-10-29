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
    #PolicyParameters = MyMicrogrid.Brain.policy_net(x)
    #μ_hat = PolicyParameters[1,:]
    #σ_hat = deepcopy(PolicyParameters[2,:])
    #σ_hat = softplus.(σ_hat) .+ 1e-3
    μ_hat = MyMicrogrid.Brain.policy_net(x)
    σ_hat = 0.1
    #MyMicrogrid.Brain.cPolicyOutputLayerType == "sigmoid" ? σ_hat = 0.01 : σ_hat = 1.0
    Policy = Distributions.Normal.(μ_hat, σ_hat)
    #println("Policy: $Policy")
    iScoreFunction = -Distributions.logpdf.(Policy, Actions)
    #println("iScoreFunction: $iScoreFunction")
    iLoss = sum(iScoreFunction .* A)
    #iEntropy = sum(Distributions.entropy.(Policy))
    println("Actor loss function: $iLoss")
    # return iLoss - ι*iEntropy
    return iLoss
end

function CriticLoss(x, y; ξ = 0.5)
    iCriticLoss = ξ*Flux.mse(MyMicrogrid.Brain.value_net(x), y)
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
    #println("Actor parameters: ", Flux.params(Microgrid.Brain.policy_net))
    #println("Actor parameters: ", Flux.params(Microgrid.Brain.policy_net)[1][1:3])
    #println("Critic parameters: ", Flux.params(Microgrid.Brain.value_net)[1][1:3])
end

function Learn!(Microgrid::Microgrid, step::Tuple, dictNormParams::Dict, iLookBack::Int)
    State, Action, ActualAction, Reward, NextState, v, v′, bTerminal = step
#    if bTerminal
#        R = Reward  #TD target
#    else
#        R = Reward + Microgrid.Brain.β * v′ #TD target
#    end
    R = Reward + Microgrid.Brain.β * v′ #TD target
    x = @pipe deepcopy(State) |> NormaliseState!(_, dictNormParams, iLookBack) # in usual circumstances that's StateForLearning
    A = R - v                               # TD error
    y = R
    Flux.train!(ActorLoss, Flux.params(Microgrid.Brain.policy_net), [(x,Action,A)], ADAM(Microgrid.Brain.ηₚ)) # Actor learns based on TD error
    Flux.train!(CriticLoss, Flux.params(Microgrid.Brain.value_net), [(x,y)], ADAM(Microgrid.Brain.ηᵥ))        # Critic learns based on TD target
end

function ChargeOrDischargeBattery!(Microgrid::Microgrid, Action::Float64, iLookBack::Int, bLog::Bool)
    # iConsumptionMismatch = Microgrid.State[1]
    #if Microgrid.Brain.cPolicyOutputLayerType == "sigmoid"
    #     iChargeDischargeVolume = deepcopy(Action) * iConsumptionMismatch
    #else
    #    iChargeDischargeVolume = deepcopy(Action)
    #end
    iChargeDischargeVolume = deepcopy(Action) * Microgrid.EnergyStorage.iMaxCapacity
    # iChargeDischargeVolume = deepcopy(Action)
    if iChargeDischargeVolume >= 0
        iMaxPossibleCharge = min(Microgrid.EnergyStorage.iChargeRate,
            Microgrid.EnergyStorage.iMaxCapacity - Microgrid.EnergyStorage.iCurrentCharge * Microgrid.EnergyStorage.iMaxCapacity)
        iCharge = min(iMaxPossibleCharge, iChargeDischargeVolume)
        iChargeNormalised = iCharge / Microgrid.EnergyStorage.iMaxCapacity
        Microgrid.EnergyStorage.iCurrentCharge += iChargeNormalised
        #if Microgrid.Brain.cPolicyOutputLayerType == "sigmoid"
        #    ActualAction = iCharge / iConsumptionMismatch
        #else
        #    ActualAction = iCharge
        #end
        ActualAction = iChargeNormalised
        # ActualAction = iCharge
        if bLog
            println("Actual charge of battery: ", round(iCharge; digits = 2))
        end
    else
        iMaxPossibleDischarge = max(Microgrid.EnergyStorage.iDischargeRate,
            -Microgrid.EnergyStorage.iCurrentCharge * Microgrid.EnergyStorage.iMaxCapacity)
        iDischarge = max(iMaxPossibleDischarge, iChargeDischargeVolume)
        iDischargeNormalised = iDischarge / Microgrid.EnergyStorage.iMaxCapacity
        Microgrid.EnergyStorage.iCurrentCharge += iDischargeNormalised
        #if Microgrid.Brain.cPolicyOutputLayerType == "sigmoid"
        #    ActualAction = iDischarge / iConsumptionMismatch
        #else
        #    ActualAction = iDischarge
        #end
        ActualAction = iDischargeNormalised
        # ActualAction = iDischarge
        if bLog
            println("Actual discharge of battery: ", round(iDischarge; digits = 2))
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
    # iMicrogridVolume = deepcopy(ActualAction) * State[1]
    # iMicrogridVolume = deepcopy(ActualAction)
    # iGridVolume = State[1] - iMicrogridVolume
    iGridVolume = State[1] - ActualAction * Microgrid.EnergyStorage.iMaxCapacity
    #iGridPrice = Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices.iMedian[1]
    #iReward = iGridVolume * iGridPrice
    #dictRewards = GetReward(Microgrid, iTimeStep)
    if iGridVolume >= 0
        #iReward = iGridVolume * dictRewards["iPriceSell"]
        iReward = iGridVolume * Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices.i30Centile[1]
    else
    #iReward = iGridVolume * dictRewards["iPriceBuy"]
        iReward = iGridVolume * Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices.i70Centile[1]
    end

    #if iMicrogridVolume >= 0
    #    iMicrogridReward = iMicrogridVolume * Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices.i30Centile[1]
    #else
    #    iMicrogridReward = iMicrogridVolume * Microgrid.DayAheadPricesHandler.dfQuantilesOfPrices.i70Centile[1]
    #end
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
function Forward(Microgrid::Microgrid, state::Vector, bσFixed::Bool, dictNormParams::Dict, iLookBack::Int,
        bPrintPolicyParams::Bool)
    # StateForLearning = deepcopy(Microgrid.State)
    StateForLearning = @pipe deepcopy(Microgrid.State) |> NormaliseState!(_, dictNormParams, iLookBack)
    μ_hat = Microgrid.Brain.policy_net(StateForLearning)    # wektor p-w na bazie sieci aktora
    σ_hat = 0.1
    # PolicyParameters = MyMicrogrid.Brain.policy_net(StateForLearning)
    # μ_hat = PolicyParameters[1,:]
    # σ_hat = deepcopy(PolicyParameters[2,:])
    # σ_hat = softplus.(σ_hat) .+ 1e-3
    if bPrintPolicyParams
        println("Policy params: $μ_hat, $σ_hat")
    end
    Policy = Distributions.Normal.(μ_hat, σ_hat)
    #MyMicrogrid.Brain.cPolicyOutputLayerType == "sigmoid" ? iσFixed = 0.01 : iσFixed = 1.0
    #if bσFixed
    #    Policy = Distributions.Normal(μ_policy, iσFixed)
    #else
    #    println("Not yet implemented")
    #    return nothing
    #end
    v = Microgrid.Brain.value_net(StateForLearning)[1]   # wektor f wartosic na bazie sieci krytyka
    return Policy[1],v
end


function Act!(Microgrid::Microgrid, iTimeStep::Int, iHorizon::Int, iLookBack::Int,
    dictNormParams::Dict, bLearn::Bool, bLog::Bool)
    #Random.seed!(72945)
    CurrentState = deepcopy(Microgrid.State)
    Policy, v = Forward(Microgrid, CurrentState, true, dictNormParams, iLookBack, true)
    Action = rand(Policy)
    ActionForPrint = round(Action * 100; digits = 2)
    if bLog
        # println("Time step $iTimeStep, intended action $Action kW, prod-cons mismatch ", CurrentState[iLookBack+1])
        println("Currently free storage capacity: ", Microgrid.State[length(Microgrid.State)] * Microgrid.EnergyStorage.iMaxCapacity)
        println("Intended action $ActionForPrint % of storage capacity")
        println("Current prod-cons mismatch ", round(CurrentState[1]; digits = 2))
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
    _, v′ = Forward(Microgrid, NextState, true, dictNormParams, iLookBack, false)
    if iTimeStep + 1 == iHorizon
        bTerminal = true
        # v′ = 0
    else
        bTerminal = false
    end
    step = (deepcopy(CurrentState), deepcopy(Action), deepcopy(ActualAction),
        deepcopy(iReward), deepcopy(NextState), deepcopy(v), deepcopy(v′), deepcopy(bTerminal))
    Remember!(Microgrid, step)

    #if bLearn
        #Learn!(Microgrid, step, dictNormParams, iLookBack)
        #println("Learning")
    #end

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
