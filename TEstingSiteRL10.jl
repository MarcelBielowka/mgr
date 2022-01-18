MyMicrogrid = GetMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households, "identity", 2,
    200, 128, 0.0001, 0.0001, 1.0)
RandomMicrogrid = deepcopy(MyMicrogrid)
Random.seed!(72945)

dRunStartTrain = @pipe Dates.Date("2019-04-01") |> Dates.dayofyear |> _*24 |> _- 23
dRunEndTrain = @pipe Dates.Date("2019-09-30") |> Dates.dayofyear |> _*24 |> _-1
dRunStartTest = dRunEndTrain + 1
dRunEndTest = @pipe Dates.Date("2019-12-30") |> Dates.dayofyear |> _*24 |> _-1
iEpisodeLength = dRunStartTest - dRunEndTest |> abs
iEpisodeLengthTrain = dRunStartTrain - dRunEndTrain |> abs

InitialTestResult = Run!(RandomMicrogrid, 1, 2, 0.5, dRunStartTest, dRunEndTest, false, false)
@time TrainResult = Run!(MyMicrogrid, 100, 24, 0.5, dRunStartTrain, dRunEndTrain, true, true)

abc = Juno.@enter Run!(MyMicrogrid, 1, 24, 0.5, dRunStartTrain, dRunEndTrain + 3, true, true)

iLookBack = 24
iEpisodes = length(MyMicrogrid.RewardHistory)
StatsPlots.plot(MyMicrogrid.RewardHistory, title = "Learning history, look forward = $iLookBack",
    label = "β = 1", legend = :topright)
plot!(Microgrid990.RewardHistory, label = "β = 0.99")
plot!(Microgrid995.RewardHistory, label = "β = 0.995")
plot!(Microgrid999.RewardHistory, label = "β = 0.999")
MyMicrogrid.State

MyMicrogrid.Brain.memory

TrainResult = Juno.@enter Run!(MyMicrogrid, 1, 1,
    dRunStartTrain+8, dRunStartTrain+9, true, true)

abc = FineTuneTheMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households,
    ["identity"], 100,
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [1], [0.5], [0.99, 0.999],
    [0.0001, 0.001], [0.0001, 0.001],
    [50, 200], [64, 128])

abc = FineTuneTheMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households,
    ["identity"], 100,
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [1], [0.5], [0.99, 0.999],
    [0.0001, 0.001], [0.0001, 0.001],
    [50, 200], [64, 128])

abc = FineTuneTheMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households,
    ["identity"], 100,
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [1], [0.5], [0.99, 0.995, 0.999, 1],
    [0.0001], [0.0001],
    [200], [128])

LetsTwistAgain = FineTuneTheMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households,
    ["identity"], 100,
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [1], [0.5], [0.999],
    [0.0001], [0.0001],
    [200], [128])

[50, 100, 200]



MyMicrogrid = abc[Dict("iHiddenLayerNeuronsCritic" => 128,
    "iGridCoefficient" => 0.500,
    "iCriticLearningRate" => 0.000100,
    "iActorLearningRate" => 0.000100,
    "iHiddenLayerNeuronsActor" => 200,
    "iβ" => 1.0,
    "cPolicyOutputLayerType" => "identity",
    "iLookBack" => 1
)]["MyMicrogrid"]

Microgrid990 = abc[Dict("iHiddenLayerNeuronsCritic" => 128,
    "iGridCoefficient" => 0.500,
    "iCriticLearningRate" => 0.000100,
    "iActorLearningRate" => 0.000100,
    "iHiddenLayerNeuronsActor" => 200,
    "iβ" => 0.99,
    "cPolicyOutputLayerType" => "identity",
    "iLookBack" => 1
)]["MyMicrogrid"]

Microgrid995 = abc[Dict("iHiddenLayerNeuronsCritic" => 128,
    "iGridCoefficient" => 0.500,
    "iCriticLearningRate" => 0.000100,
    "iActorLearningRate" => 0.000100,
    "iHiddenLayerNeuronsActor" => 200,
    "iβ" => 0.995,
    "cPolicyOutputLayerType" => "identity",
    "iLookBack" => 1
)]["MyMicrogrid"]

Microgrid999 = abc[Dict("iHiddenLayerNeuronsCritic" => 128,
    "iGridCoefficient" => 0.500,
    "iCriticLearningRate" => 0.000100,
    "iActorLearningRate" => 0.000100,
    "iHiddenLayerNeuronsActor" => 200,
    "iβ" => 0.999,
    "cPolicyOutputLayerType" => "identity",
    "iLookBack" => 1
)]["MyMicrogrid"]

Microgrid1000 = abc[Dict("iHiddenLayerNeuronsCritic" => 128,
    "iGridCoefficient" => 0.500,
    "iCriticLearningRate" => 0.000100,
    "iActorLearningRate" => 0.000100,
    "iHiddenLayerNeuronsActor" => 200,
    "iβ" => 1.0,
    "cPolicyOutputLayerType" => "identity",
    "iLookBack" => 1
)]["MyMicrogrid"]

@pipe keys(LetsTwistAgain) |> collect |> _[1] |> values |> collect

MyMicrogrid.Brain.memory = []

Flux.params(Chupacabra.Brain.value_net)[5]

RandomMicrogrid.Brain.memory

Normal(0.3, 0.5)
