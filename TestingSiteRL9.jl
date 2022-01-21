MyMicrogrid = GetMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households, "identity", 2,
    100, 100, 0.0001, 0.0001, 1.0)
RandomMicrogrid = deepcopy(MyMicrogrid)
Random.seed!(72945)

dRunStartTrain = @pipe Dates.Date("2019-04-01") |> Dates.dayofyear |> _*24 |> _- 23
dRunEndTrain = @pipe Dates.Date("2019-09-30") |> Dates.dayofyear |> _*24 |> _-1
dRunStartTest = dRunEndTrain + 1
dRunEndTest = @pipe Dates.Date("2019-12-30") |> Dates.dayofyear |> _*24 |> _-1
iEpisodeLength = dRunStartTest - dRunEndTest |> abs
iEpisodeLengthTrain = dRunStartTrain - dRunEndTrain |> abs

InitialTestResult = Run!(RandomMicrogrid, 1, 2, 0.5, dRunStartTest, dRunEndTest, false, false)
@time TrainResult = Run!(MyMicrogrid, 100, 2, 0.5, dRunStartTrain, dRunEndTrain, true, true)

abc = Juno.@enter Run!(MyMicrogrid, 1, 24, 0.5, dRunStartTrain, dRunEndTrain + 3, true, true)

AugustMicrogrid = deepcopy(MyMicrogrid)
JulyMicrogrid = deepcopy(MyMicrogrid)

iLookBack = 2
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

### Tuning the episode length ###
TuningEpisodesLength = @time FineTuneTheMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households,
    ["identity"], [25, 50, 75, 100],
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [2], [0.5], [0.999],
    [0.0001], [0.0001],
    [100], [100])
EpisodesLengthAug = GetDataForPlottingFromResultsHolder(TuningEpisodesLength)

### Tuning commercial params ###
TuningCommercialParams = @time FineTuneTheMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households,
    ["identity"], [40],
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [0, 2, 6, 12, 24], [0.9, 0.7, 0.5, 0.3], [0.999],
    [0.0001], [0.0001],
    [100], [100])
CommercialParamsAug = GetDataForPlottingFromResultsHolder(TuningCommercialParams)

### Tuning β ###
TuningBeta = @time FineTuneTheMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households,
    ["identity"], [40],
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [2], [0.7], [0.99, 0.995, 0.999, 1.0],
    [0.0001], [0.0001],
    [100], [100])
BetaParamsAug = GetDataForPlottingFromResultsHolder(TuningBeta)

### Tuning neural network ###
TuningNNParams = @time FineTuneTheMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households,
    ["identity"], [40],
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [2], [0.7], [0.999],
    [0.0001, 0.001], [0.0001, 0.001],
    [50, 100, 200], [50, 100, 200])
NNParamsAug = GetDataForPlottingFromResultsHolder(TuningNNParams)


### Plotting ###
#plots episodes length
EpisodesLengthAugStacked = stack(EpisodesLengthAug, [:iInitialTestResult, :iResultAfterTraining])

tuv = @pipe EpisodesLengthAug |> groupby(_, :iEpisodes) |>
    combine(_, :iResultAfterTraining => mean)

@df filter(row -> row.iEpisodes == 25, EpisodesLengthAug) plot(
    :iTrainResult,
    color = RGB(100/255, 0, 0),
    label = "25 episodes",
    xlabel = "Number of episodes",
    ylabel = "Cumulated reward at the end of episode"
)

@df filter(row -> row.iEpisodes == 50, EpisodesLengthAug) plot!(
    :iTrainResult,
    color = RGB(192/255, 0, 0),
    label = "50 episodes"
)

@df filter(row -> row.iEpisodes == 75, EpisodesLengthAug) plot!(
    :iTrainResult,
    color = RGB(100/255, 100/255, 100/255),
    label = "75 episodes"
)

@df filter(row -> row.iEpisodes == 100, EpisodesLengthAug) plot!(
    :iTrainResult,
    color = RGB(192/255, 192/255, 192/255),
    label = "100 episodes"
)
savefig("C:/Users/Marcel/Desktop/mgr/graphs/EpisodesTuning.png")

EpisodesRewardAverage = @df EpisodesLengthAugStacked groupedboxplot(string.(:iEpisodes), :value, group = :variable,
    label = ["Result before training" "Result after training"], legend = :right,
    color = [RGB(192/255, 192/255, 192/255) RGB(192/255, 0, 0)],
    xlabel = "Number of episodes in the learning process",
    ylabel = "Average cumulative reward in episode - testing period")
savefig(EpisodesRewardAverage, "C:/Users/Marcel/Desktop/mgr/graphs/EpisodesTuningAverage.png")

# plots β
BetaParamsAugStacked = stack(BetaParamsAug, [:iInitialTestResult, :iResultAfterTraining])
BetaParamsAugStackedTraining = stack(BetaParamsAug, [:iTrainResult], :iβ)
rename!(BetaParamsAugStackedTraining, [:iβ, :cName, :iTrainResult])

PlotBetaTuning = @df BetaParamsAugStackedTraining StatsPlots.plot(
    repeat(collect(1:1:40), 4),
    :iTrainResult,
    group = :iβ,
    legend = :topleft,
    legendtitle = "β",
    legendtitlefontsize = 10,
    legendfontsize = 7,
    xlabel = "Number of epsiodes",
    ylabel = "Cumulated reward",
    color = [RGB(192/255, 0, 0) RGB(192/255, 192/255, 0) RGB(192/255, 192/255, 192/255) RGB(0, 0, 0)])

savefig(PlotBetaTuning, "C:/Users/Marcel/Desktop/mgr/graphs/BetaTuning.png")

#@df BetaParamsAug groupedboxplot(string.(:iβ), :iResultAfterTraining)
#@df BetaParamsAug groupedboxplot!(string.(:iβ), :iInitialTestResult)

#@df BetaParamsAug violin(string.(:iβ), :iResultAfterTraining, side = :left)
#@df BetaParamsAug violin!(string.(:iβ), :iInitialTestResult, side = :right)

PlotBetaTuningAvg = @df BetaParamsAugStacked groupedboxplot(
    string.(:iβ),
    :value,
    group = :variable,
    label = ["Result before training" "Result after training"],
    legend = :right,
    color = [RGB(192/255, 192/255, 192/255) RGB(192/255, 0, 0)],
    xlabel = "β",
    ylabel = "Cumulated reward, testing period"
    )
savefig(PlotBetaTuningAvg, "C:/Users/Marcel/Desktop/mgr/graphs/BetaTuningAvg.png")

# plots commercial params
CommercialParamsAugTransformed = @pipe CommercialParamsAug |>
    groupby(_, [:iGridLongVolumeCoefficient]) |>
    DataFrames.transform(_, [:iTrainResult => minimum => :iTrainResultMin,
                             :iTrainResult => maximum => :iTrainResultMax])
insertcols!(CommercialParamsAugTransformed,
    :iTrainResultNormalised =>
    (CommercialParamsAugTransformed.iTrainResult .- CommercialParamsAugTransformed.iTrainResultMin) ./
        (CommercialParamsAugTransformed.iTrainResultMax .- CommercialParamsAugTransformed.iTrainResultMin)
    )
PlotCommercialParams = @df CommercialParamsAugTransformed StatsPlots.plot(
    repeat(collect(1:1:40), 20),
    string.(:iGridLongVolumeCoefficient),
    :iTrainResultNormalised,
    line_z = Int.(:iLookBack),
    group = (:iGridLongVolumeCoefficient, :iLookBack),
    camera = (75, 30),
    # vlinecolor = :iLookBack,
    # linecolor = [RGB(30/255, 0, 0) RGB(100/255, 0, 0) RGB(192/255, 0, 0) RGB(30/255, 30/255, 30/255) RGB(100/255, 100/255, 100/255) RGB(140/255, 140/255, 140/255)],
    linecolor = :sun,
    # legend = :none,
    label = "",
    linewidth = 3,
    linealpha = 0.7,
    xlabel = "",
    xrotation = -45,
    xguide_position = :right,
    # framestyle = :zerolines,
    # xguidefontsize = 18,
    ylabel = "κ coefficient" ,
    zlabel = "Reward in the episode, normalised",
    size = (800, 600),
    colorbar_title = "\n\n\n Look ahead horizon",
    colorbar_ticks = [0 2 4 6 12 24],
    left_margin = 2Plots.mm,
    right_margin = 2Plots.mm
    # levels = [i for i in 0:24]
)

savefig(PlotCommercialParams, "C:/Users/Marcel/Desktop/mgr/graphs/CommercialParamsTuning.png")

# plots NN
NNParamsAugTransformed = @pipe NNParamsAug |>
    groupby(_, [:iActorLearningRate, :iCriticLearningRate, :iHiddenLayerNeuronsActor, :iHiddenLayerNeuronsCritic, ]) |>
    combine(_, :iResultAfterTraining => mean => :Avg)

PlotNNParams = @df NNParamsAugTransformed StatsPlots.scatter(
    string.(:iHiddenLayerNeuronsActor),
    string.(:iHiddenLayerNeuronsCritic),
    :Avg,
    marker_z = :iActorLearningRate,
    group = (:iActorLearningRate, :iCriticLearningRate),
    marker = [:circle :square :star :utriangle],
    alpha = 0.3,
    markersize = 7,
    camera = (50, 20),
    legend = :left,
    legendtitle = "Actor and critic learning rates",
    legendtitlefontsize = 8,
    legendfontsize = 8,
    legendfontvalign = :center,
    colorbar = :none,
    color = :sun,
    zlabel = "Average reward, testing period",
    xlabel = "Number of neurons \n in hidden layer - actor",
    ylabel = "Number of neurons \n in hidden layer - critic",
    xguidefontsize= 8,
    guidefonthalign = :left,
    yguidefontsize = 8,
    yguidefontvalign = :top,
    size = (800, 600),
    left_margin = 2Plots.mm,
    right_margin = 5Plots.mm,
    bottom_margin = 5Plots.mm,
    zguidefontrotation = -30
)

savefig(PlotNNParams, "C:/Users/Marcel/Desktop/mgr/graphs/NNParamsTuning.png")

p1data = filter(row -> (row.iActorLearningRate==0.0001 && row.iCriticLearningRate==0.0001 ), NNParamsAug)
p2data = filter(row -> (row.iActorLearningRate==0.001 && row.iCriticLearningRate==0.0001 ), NNParamsAug)
p3data = filter(row -> (row.iActorLearningRate==0.001 && row.iCriticLearningRate==0.001 ), NNParamsAug)
p4data = filter(row -> (row.iActorLearningRate==0.0001 && row.iCriticLearningRate==0.001 ), NNParamsAug)

p1 = @df p1data StatsPlots.plot(
    repeat(collect(1:1:40), 9),
    string.(:iHiddenLayerNeuronsCritic),
    :iTrainResult,
    line_z = :iHiddenLayerNeuronsActor,
    group = (:iHiddenLayerNeuronsActor, :iHiddenLayerNeuronsCritic),
    camera = (70, 20),
    linecolor = :sun,
    lw = 3,
    legend = :none,
    title = "ηₐ = 0.0001, η̧ᵪ = 0.0001",
    titlefontsize = 10,
    ylabelfontsize = 7,
    zlabelfontsize = 7,
    ylabel = "Neurons in hidden layer - critic",
    zlabel = "Reward in the episode",
    zlim = (24000, 40000),
    formatter = :plain
)

p2 = @df p2data StatsPlots.plot(
    repeat(collect(1:1:40), 9),
    string.(:iHiddenLayerNeuronsCritic),
    :iTrainResult,
    line_z = :iHiddenLayerNeuronsActor,
    group = (:iHiddenLayerNeuronsActor, :iHiddenLayerNeuronsCritic),
    camera = (70, 30),
    # vlinecolor = :iLookBack,
    linecolor = :sun,
    lw = 3,
    legend = :none,
    title = "ηₐ = 0.001, η̧ᵪ = 0.0001",
    titlefontsize = 10,
    ylabel = "Neurons in hidden layer - critic",
    ylabelfontsize = 7,
    zlabelfontsize = 7,
    zlabel = "Reward in the episode",
    zlim = (24000, 40000),
    formatter = :plain
    # zlim = (-150, 800)
)

p3 = @df p3data StatsPlots.plot(
    repeat(collect(1:1:40), 9),
    string.(:iHiddenLayerNeuronsCritic),
    :iTrainResult,
    line_z = :iHiddenLayerNeuronsActor,
    group = (:iHiddenLayerNeuronsActor, :iHiddenLayerNeuronsCritic),
    camera = (70, 30),
    # vlinecolor = :iLookBack,
    linecolor = :sun,
    lw = 3,
    legend = :none,
    title = "ηₐ = 0.0001, η̧ᵪ = 0.001",
    titlefontsize = 10,
    ylabelfontsize = 7,
    zlabelfontsize = 7,
    ylabel = "Neurons in hidden layer - critic",
    zlabel = "Reward in the episode",
    zlim = (24000, 40000),
    formatter = :plain
    # zlim = (-150, 800)
)

p4 = @df p4data StatsPlots.plot(
    repeat(collect(1:1:40), 9),
    string.(:iHiddenLayerNeuronsCritic),
    :iTrainResult,
    line_z = :iHiddenLayerNeuronsActor,
    group = (:iHiddenLayerNeuronsActor, :iHiddenLayerNeuronsCritic),
    camera = (70, 30),
    # vlinecolor = :iLookBack,
    linecolor = :sun,
    lw = 3,
    legend = :none,
    title = "ηₐ = 0.001, η̧ᵪ = 0.001",
    titlefontsize = 10,
    ylabelfontsize = 7,
    zlabelfontsize = 7,
    ylabel = "Neurons in hidden layer - critic",
    zlabel = "Reward in the episode",
    zlim = (24000, 40000),
    formatter = :plain
    # zlim = (-150, 800)
)

q = @layout [
         [grid(4,1)] b{0.4w}
    ]

p5 = @df p4data StatsPlots.plot(
    :iHiddenLayerNeuronsActor,
    :iHiddenLayerNeuronsCritic, xlim = (4,5),
    group = (:iHiddenLayerNeuronsActor, :iHiddenLayerNeuronsCritic),
    label = "",
    legend = :topleft, framestyle = :none,
    line_z = :iHiddenLayerNeuronsActor,
    colorbar = true,
    colorbar_ticks = [50 100 200],
    colorbar_title = "Neurons in hidden layer - actor",
    colorbar_titlefontsize = 10,
    colorbar_tickfontsize = 3,
    color = :sun)

PlotNNTrainingResults = plot(p1, p2, p3, p4, p5,
    layout = q, size = (800, 600),
    left_margin = 5Plots.mm,
    right_margin = 5Plots.mm,
    legend = :none)

savefig(PlotNNTrainingResults, "C:/Users/Marcel/Desktop/mgr/graphs/NNParamsTuningFurther.png")

##### Members tuning
MembersTuning = FineTuneMembers(DayAheadPowerPrices, Weather,
    2000.0, 11.5, 3.0, 20.0,
    [1, 3, 5],
    dfRawEnergyConsumption, dfRawConsHistory, 2, 2019, 0.1, 20.0,
    0.55, 0.0035, 45, [400, 600, 800],
    13.5, 7.0, -5.0, [0, 20, 40, 80, 160],
    Households,
    ["identity"], [40],
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [2], [0.7], [0.999],
    [0.0001], [0.0001],
    [100], [100])

MembersTuning = FineTuneMembers(DayAheadPowerPrices, Weather,
    2000.0, 11.5, 3.0, 20.0,
    [3],
    dfRawEnergyConsumption, dfRawConsHistory, 2, 2019, 0.1, 20.0,
    0.55, 0.0035, 45, [400],
    13.5, 7.0, -5.0, [10, 20],
    Households,
    ["identity"], [11],
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [2], [0.7], [0.999],
    [0.0001], [0.0001],
    [100], [100])

FinalMicrogrids = [MembersTuning[i].Result[1].FinalMicrogrid for i in 1:length(MembersTuning)]
LOEE_base = [FinalMicrogrids[i].Brain.memory[j][1][1] * (1 - FinalMicrogrids[i].Brain.memory[j][3]) for j in 1:length(FinalMicrogrids[1].Brain.memory), i in 1:length(MembersTuning)]
LOEE = [sum(LOEE_base[:, i] .< 0)/length(LOEE_base[:, i]) for i in 1:size(LOEE_base,2)]
LOLE = [sum((LOEE_base[:, i] .< 0) .* LOEE_base[:, i]) / length(LOEE_base[:, i]) for i in 1:size(LOEE_base,2)]

iTurbines = [MembersTuning[i].iTurbines for i in 1:length(MembersTuning)]
iPVPanels = [MembersTuning[i].iPVPanels for i in 1:length(MembersTuning)]
iStorageCells = [MembersTuning[i].iStorageCells for i in 1:length(MembersTuning)] .+20
iResults = [MembersTuning[i].Result[1] for i in 1:length(MembersTuning)]

iAverageResultAfterTraining = [mean(iResults[i].ResultAfterTraining) for i in 1:length(iResults)]

TotalProd = [iResults[i].MyMicrogrid.dfTotalProduction for i in 1:length(iResults)]
TotalCons = [iResults[i].MyMicrogrid.dfTotalConsumption for i in 1:length(iResults)]
TotalNetLoadTrain = [TotalProd[i].TotalProduction[dRunStartTrain:dRunEndTrain] .-
    TotalCons[i].TotalConsumption[dRunStartTrain:dRunEndTrain] for i in 1:length(iResults)]

TotalNetLoadTest = [TotalProd[i].TotalProduction[dRunStartTest:dRunEndTest] .-
    TotalCons[i].TotalConsumption[dRunStartTest:dRunEndTest] for i in 1:length(iResults)]

CoverageTrain = [TotalProd[i].TotalProduction[dRunStartTrain:dRunEndTrain] .<
    TotalCons[i].TotalConsumption[dRunStartTrain:dRunEndTrain] for i in 1:length(iResults)]

CoverageTest = [TotalProd[i].TotalProduction[dRunStartTest:dRunEndTest] .<
    TotalCons[i].TotalConsumption[dRunStartTest:dRunEndTest] for i in 1:length(iResults)]

LOELTrain = [sum(CoverageTrain[i]) / length(CoverageTrain[i]) for i in 1:length(CoverageTrain)]

LOELTest = [sum(CoverageTest[i]) / length(CoverageTest[i]) for i in 1:length(CoverageTest)]

LOEETrain = [sum(CoverageTrain[i] .* TotalNetLoadTrain[i] ) / length(CoverageTrain[i]) for i in 1:length(CoverageTrain)]
LOEETest = [sum(CoverageTest[i] .* TotalNetLoadTest[i] ) / length(CoverageTest[i]) for i in 1:length(CoverageTest)]

PlotImpactsOfConsittuents = Plots.scatter(iPVPanels,
    iTurbines,
    iStorageCells,
    marker_z = iAverageResultAfterTraining,
    # group = iStorageCells,
    markershape = :hexagon,
    markersize = 6,
    alpha = 0.5,
    # markershape = [:hexagon, :utriangle, :square, :star6],
    legend = :none,
    # markershape = iStorageCells,
    color = :sun,
    zformatter = :plain,
    colorbar = true,
    camera = (75, 40),
    left_margin = 2Plots.mm,
    right_margin = 8Plots.mm,
    bottom_margin = 5Plots.mm,
    colorbar_titlefontsize = 9,
    colorbar_title = "\n\n\n\nAverage cumulative reward per episode",
    ylabel = "N of wind turbines",
    ylabelfontsize = 8,
    zlabel = "Number of storage cells",
    zlabelfontsize = 8
    )

savefig(PlotImpactsOfConsittuents, "C:/Users/Marcel/Desktop/mgr/graphs/Constituents.png")

scatter(iPVPanels,
    iTurbines,
    iStorageCells,
    marker_z = LOELTest,
    camera = (75, 40),
    markershape = :hexagon,
    markersize = 6,
    alpha = 0.5,
    legend = :none,
    colorbar = true,
    left_margin = 2Plots.mm,
    right_margin = 8Plots.mm,
    bottom_margin = 5Plots.mm,
    color = f)
f = cgrad(:sun, rev = true)


LOLE
