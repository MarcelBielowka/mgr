### Power prices ###
# Power prices table
dfPowerPricesTable = describe(DayAheadPowerPrices.dfDayAheadPrices[!, [:Price]])
describe(DayAheadPowerPrices.dfDayAheadPrices.Price)
describe(Weather.dfWeatherData.Temperature)
describe(Weather.dfWeatherData.WindSpeed)
describe(Weather.dfWeatherData.Irradiation)
dfPowerPricesTable = describe(Weather.dfWeatherData[!, [:Temperature, :WindSpeed, :Irradiation]])

#########################################
######### Power prices graphs ###########
#########################################
### Power prices graph ###
PlotPowerPrices = plot(Dates.DateTime.(Dates.year.(DayAheadPowerPrices.dfDayAheadPrices.DeliveryDate),
                                       Dates.month.(DayAheadPowerPrices.dfDayAheadPrices.DeliveryDate),
                                       Dates.day.(DayAheadPowerPrices.dfDayAheadPrices.DeliveryDate),
                                       DayAheadPowerPrices.dfDayAheadPrices.DeliveryHour),
                       DayAheadPowerPrices.dfDayAheadPrices.Price,
                       xlabel = "Delivery date",
                       ylabel = "Price [PLN/MWh]",
                       color = RGB(192/255, 0, 0),
                       legend = :none)
savefig(PlotPowerPrices, "C:/Users/Marcel/Desktop/mgr/graphs/PowerPrices.png")

### W21 & 22 power prices graph ###
dfCutOutPowerData = filter(row -> (week(row.DeliveryDate) >= 20 && week(row.DeliveryDate) <= 21),DayAheadPowerPrices.dfDayAheadPrices)
PlotWeekPowerPrices = plot(
                      Dates.DateTime.(Dates.year.(dfCutOutPowerData.DeliveryDate),
                                       Dates.month.(dfCutOutPowerData.DeliveryDate),
                                       Dates.day.(dfCutOutPowerData.DeliveryDate),
                                       dfCutOutPowerData.DeliveryHour),
                      dfCutOutPowerData.Price,
                      xlabel = "Delivery date",
                      ylabel = "Price [PLN/MWh]",
                      color = RGB(192/255, 0, 0),
                      legend = :none,
                      xticks = Dates.DateTime.(
                        Dates.year.(dfCutOutPowerData.DeliveryDate),
                        Dates.month.(dfCutOutPowerData.DeliveryDate),
                        Dates.day.(dfCutOutPowerData.DeliveryDate)
                      ),
                      xrotation = 30,
                      size = (800, 600),
                      # xgrid = false,
                      leftmargin = 10Plots.mm,
                      rightmargin = 2Plots.mm,
                      bottommargin = 5Plots.mm
                      )
savefig(PlotWeekPowerPrices, "C:/Users/Marcel/Desktop/mgr/graphs/PowerPricesWeek.png")


#########################################
##### Metheorological data graphs #######
#########################################
### Coplete sample ###
PlotTemperature = StatsPlots.plot(
        Weather.dfWeatherData.date,
        Weather.dfWeatherData.Temperature,
        xlabel = "Delivery date",
        ylabel = "Temperature [C]",
        color = RGB(192/255, 0, 0),
        legend = :none,
        xlabelfontsize = 8,
        ylabelfontsize = 8,
        xtickfontsize = 6,
        ytickfontsize = 6
)
PlotIrradiation = StatsPlots.plot(
        Weather.dfWeatherData.date,
        Weather.dfWeatherData.Irradiation,
        xlabel = "Delivery date",
        ylabel = "Irradiation [W/m2]",
        color = RGB(192/255, 0, 0),
        legend = :none,
        xlabelfontsize = 8,
        ylabelfontsize = 8,
        xtickfontsize = 6,
        ytickfontsize = 6
)
PlotWindSpeed = StatsPlots.plot(
        Weather.dfWeatherData.date,
        Weather.dfWeatherData.WindSpeed,
        xlabel = "Delivery date",
        ylabel = "Wind speed [m/s]",
        color = RGB(192/255, 0, 0),
        legend = :none,
        xlabelfontsize = 8,
        ylabelfontsize = 8,
        xtickfontsize = 6,
        ytickfontsize = 6
)
PlotWeatherData = plot(PlotTemperature, PlotIrradiation, PlotWindSpeed, layout = (3,1))
savefig(PlotWeatherData, "C:/Users/Marcel/Desktop/mgr/graphs/PlotWeatherData.png")

###Week 20 and 21 ###
dfCutOutWeatherData = filter(row -> (week(row.date) >= 20 && week(row.date) <= 21),Weather.dfWeatherData)
PlotTemperatureCutOut = StatsPlots.plot(
       dfCutOutWeatherData.date,
       dfCutOutWeatherData.Temperature,
       xlabel = "Delivery date",
       ylabel = "Temperature [C]",
       color = RGB(192/255, 0, 0),
       legend = :none,
       xlabelfontsize = 8,
       ylabelfontsize = 8,
       xtickfontsize = 6,
       ytickfontsize = 6
)
PlotIrradiationCutOut = StatsPlots.plot(
       dfCutOutWeatherData.date,
       dfCutOutWeatherData.Irradiation,
       xlabel = "Delivery date",
       ylabel = "Irradiation [W/m2]",
       color = RGB(192/255, 192/255, 192/255),
       legend = :none,
       xlabelfontsize = 8,
       ylabelfontsize = 8,
       xtickfontsize = 6,
       ytickfontsize = 6
)
PlotWindSpeedCutOut = StatsPlots.plot(
       dfCutOutWeatherData.date,
       dfCutOutWeatherData.WindSpeed,
       xlabel = "Delivery date",
       ylabel = "Wind speed [m/s]",
       color = RGB(192/255, 0, 0),
       legend = :none,
       xlabelfontsize = 8,
       ylabelfontsize = 8,
       xtickfontsize = 6,
       ytickfontsize = 6
)
PlotWeatherDataWeekly = plot(PlotTemperatureCutOut, PlotIrradiationCutOut, PlotWindSpeedCutOut, layout = (3,1))
savefig(PlotWeatherDataWeekly, "C:/Users/Marcel/Desktop/mgr/graphs/PlotWeatherDataWeekly.png")

#########################################
######## Production data graphs #########
#########################################
### Complete production ###
PlotProduction = plot(
        MyWindPark.dfWindParkProductionData.date,
        MyWindPark.dfWindParkProductionData.WindProduction,
        label = "Wind production",
        color = RGB(100/255, 100/255, 100/255),
        alpha = 0.7,
        size = (800,600),
        legendfontsize = 8,
        xlabel = "Delivery date",
        ylabel = "Production [kWh]",
        xguidefontsize = 9,
        yguidefontsize = 9,
        leftmargin = 3Plots.mm,
        rightmargin = 3Plots.mm
)
plot!(
        MyWarehouse.SolarPanels.dfSolarProductionData.date,
        MyWarehouse.SolarPanels.dfSolarProductionData.dfSolarProduction,
        color = RGB(192/255, 0,0 ),
        alpha = 0.5,
        label = "Solar Production",
        legendfontsize = 8
)
savefig(PlotProduction, "C:/Users/Marcel/Desktop/mgr/graphs/PlotProduction.png")

### Interplay of solar irradiation and solar power production ###
dfDailyPatternOfSolarProduction = filter(row -> (week(row.date) >= 20 && week(row.date) <= 21),
        MyWarehouse.SolarPanels.dfSolarProductionData)
PlotWeeklySolarProduction = plot(
        dfDailyPatternOfSolarProduction.date,
        dfDailyPatternOfSolarProduction.dfSolarProduction,
        legend = :none,
        color = RGB(192/255, 0, 0),
        alpha = 0.7,
        size = (600, 400),
        legendfontsize = 8,
        xlabel = "Delivery date",
        ylabel = "Production from \n PV panels [kWh]",
        xlabelfontsize = 8,
        ylabelfontsize = 8,
        xtickfontsize = 6,
        ytickfontsize = 6,
        leftmargin = 3Plots.mm,
        rightmargin = 3Plots.mm
)
PlotIrradiationProductionInterplay = plot(PlotWeeklySolarProduction, PlotIrradiationCutOut, layout = (2,1))
savefig(PlotIrradiationProductionInterplay, "C:/Users/Marcel/Desktop/mgr/graphs/PlotIrradiationProductionInterplay.png")

#########################################
######## Households data graphs #########
#########################################
### Using the functions from the households.jl file ###
HouseholdsJanSunPlots = RunPlots(Households.dictHouseholdsData, 1, 7)
HouseholdsJulSunPlots = RunPlots(Households.dictHouseholdsData, 7, 7; silhouettes = false)
HouseholdsJulMonPlots = RunPlots(Households.dictHouseholdsData, 7, 1; silhouettes = false)

savefig(HouseholdsJanSunPlots["PlotDataAndProfiles"],
        "C:/Users/Marcel/Desktop/mgr/graphs/ProfileJanSun.png")
savefig(HouseholdsJulSunPlots["PlotDataAndProfiles"],
        "C:/Users/Marcel/Desktop/mgr/graphs/ProfileJulSun.png")
savefig(HouseholdsJulMonPlots["PlotDataAndProfiles"],
        "C:/Users/Marcel/Desktop/mgr/graphs/ProfileJulMon.png")
savefig(HouseholdsJanSunPlots["PlotSillhouettes"],
        "C:/Users/Marcel/Desktop/mgr/graphs/HouseholdsSillhouettes.png")

#########################################
######## Warehouse data graphs ##########
#########################################
### Consignment stream ###
dfConsInData = DataFrame(:Hour => collect(keys(ArrivalsDict)), :ConsArriving => collect(values(ArrivalsDict)))
dfConsOutData = DataFrame(:Hour => collect(keys(DeparturesDict)), :ConsDeparting => collect(values(DeparturesDict)))
dfConsData = @pipe DataFrames.innerjoin(dfConsInData, dfConsOutData, on = :Hour) |>
        sort(_, order(:Hour)) |>
        stack(_, [:ConsArriving, :ConsDeparting], :Hour) |>
        rename!(_, [:Hour, :Status, :Number])
dfConsData.Status = String.(dfConsData.Status)

PlotExpectedConsignmentsStream = @df dfConsData StatsPlots.plot(:Hour, :Number, group = :Status,
        label = ["Consignments arriving" "Consignments departing"],
        legend = :topleft,
        lw = 2,
        color = [RGB(192/255, 0, 0) RGB(100/255, 100/255, 100/255)],
        padding = (0.0,0.0))
savefig(PlotExpectedConsignmentsStream,
        "C:/Users/Marcel/Desktop/mgr/graphs/ExpectedConsignmentsStream.png")

### Weekly power consumption ###
PlotWarehouseConsumption = plot(MyWarehouse.dfEnergyConsumption.Consumption[1:24*7],
        lw = 2,
        color = RGB(192/255,0,0),
        xlabel = "Hour of the week",
        ylabel = "Power consumption [kWh]",
        legend = :none)
savefig(PlotWarehouseConsumption,
        "C:/Users/Marcel/Desktop/mgr/graphs/WarehousePowerConsumption.png")

#########################################
##### Episodes length tuning graphs #####
#########################################
EpisodesLengthAugStacked = stack(EpisodesLengthAug, [:iInitialTestResult, :iResultAfterTraining])

### Training period ###
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

### Testing period ###
EpisodesRewardAverage = @df EpisodesLengthAugStacked groupedboxplot(string.(:iEpisodes), :value, group = :variable,
    label = ["Result before training" "Result after training"], legend = :right,
    color = [RGB(192/255, 192/255, 192/255) RGB(192/255, 0, 0)],
    xlabel = "Number of episodes in the learning process",
    ylabel = "Cumulated reward, testing period",
    xlabelfontsize = 8,
    ylabelfontsize = 8)
savefig(EpisodesRewardAverage, "C:/Users/Marcel/Desktop/mgr/graphs/EpisodesTuningAverage.png")


#########################################
############ β tuning graphs ############
#########################################
BetaParamsAugStacked = stack(BetaParamsAug, [:iInitialTestResult, :iResultAfterTraining])
BetaParamsAugStackedTraining = stack(BetaParamsAug, [:iTrainResult], :iβ)
rename!(BetaParamsAugStackedTraining, [:iβ, :cName, :iTrainResult])

### Training period ###
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

### Testing period ###
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


#########################################
####### Commercial tuning graphs ########
#########################################
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
    linecolor = :sun,
    label = "",
    linewidth = 3,
    linealpha = 0.7,
    xlabel = "",
    xrotation = -45,
    xguide_position = :right,
    ylabel = "κ coefficient" ,
    zlabel = "Reward in the episode, normalised",
    size = (800, 600),
    colorbar_title = "\n\n\n Look ahead horizon",
    colorbar_ticks = [0 2 4 6 12 24],
    left_margin = 2Plots.mm,
    right_margin = 2Plots.mm
)
savefig(PlotCommercialParams, "C:/Users/Marcel/Desktop/mgr/graphs/CommercialParamsTuning.png")




#########################################
#### ANN hyperparameter tuning graphs ###
#########################################
### Testing period ###
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

### Training period ###
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
)
p3 = @df p3data StatsPlots.plot(
    repeat(collect(1:1:40), 9),
    string.(:iHiddenLayerNeuronsCritic),
    :iTrainResult,
    line_z = :iHiddenLayerNeuronsActor,
    group = (:iHiddenLayerNeuronsActor, :iHiddenLayerNeuronsCritic),
    camera = (70, 30),
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
)
p4 = @df p4data StatsPlots.plot(
    repeat(collect(1:1:40), 9),
    string.(:iHiddenLayerNeuronsCritic),
    :iTrainResult,
    line_z = :iHiddenLayerNeuronsActor,
    group = (:iHiddenLayerNeuronsActor, :iHiddenLayerNeuronsCritic),
    camera = (70, 30),
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

#########################################
###### Members sesnitivity graphs #######
#########################################
### Data extraction ###
ResultsConstituentsPerConfig = @pipe ResultsConstituents |>
    groupby(_, [:iEpisode, :iPVPanels, :iTurbines, :iStorageCells]) |>
    combine(_, :iLOLE => mean => :iLOLE,
                :iLOEE => mean => :iLOEE,
                :iLOLERandom => mean=> :iLOLERandom,
                :iLOEERandom => mean=> :iLOEERandom)

ResultsConstituentsAvg = @pipe ResultsConstituentsPerConfig |>
    groupby(_, [:iEpisode, :iPVPanels, :iTurbines, :iStorageCells]) |>
    combine(_, :iLOLE => mean => :iLOLE,
                :iLOLE => std => :iLOLEStd,
                :iLOLERandom => mean => :iLOLERandom,
                :iLOLERandom => std => :iLOLERandomStd,
                :iLOEE => mean => :iLOEE,
                :iLOEE => std => :iLOEEstd,
                :iLOEERandom => mean => :iLOEERandom,
                :iLOEERandom => std => :iLOEERandomstd,
                )

iTurbines = [MembersTuning[i].iTurbines for i in 1:length(MembersTuning)]
iPVPanels = [MembersTuning[i].iPVPanels for i in 1:length(MembersTuning)]
iStorageCells = [MembersTuning[i].iStorageCells for i in 1:length(MembersTuning)] .+20
iResults = [MembersTuning[i].Result[1] for i in 1:length(MembersTuning)]

iAverageResultAfterTraining = [mean(iResults[i].ResultAfterTraining) for i in 1:length(iResults)]

### Testing period ###
PlotImpactsOfConsittuents = Plots.scatter(
    string.(iPVPanels),
    string.(iTurbines),
    string.(iStorageCells),
    marker_z = iAverageResultAfterTraining,
    markershape = :hexagon,
    markersize = 6,
    alpha = 0.8,
    legend = :none,
    color = :sun,
    zformatter = :plain,
    colorbar = true,
    camera = (75, 40),
    left_margin = 2Plots.mm,
    right_margin = 8Plots.mm,
    bottom_margin = 5Plots.mm,
    colorbar_titlefontsize = 9,
    colorbar_title = "\n\n\n\nAverage cumulative reward",
    ylabel = "N of wind turbines",
    ylabelfontsize = 8,
    zlabel = "Number of storage cells",
    zlabelfontsize = 8
    )
savefig(PlotImpactsOfConsittuents, "C:/Users/Marcel/Desktop/mgr/graphs/Constituents.png")

groupby(ResultsConstituentsAvg, [:iPVPanels, :iTurbines, :iStorageCells])[20]
groupby(ResultsConstituentsAvg, [:iPVPanels, :iTurbines, :iStorageCells])[17]

### LOLE and LOEE graphs ###
PlotLOLE = scatter(
    string.(ResultsConstituentsAvg.iPVPanels),
    string.(ResultsConstituentsAvg.iTurbines),
    string.(ResultsConstituentsAvg.iStorageCells.+20),
    marker_z = ResultsConstituentsAvg.iLOLE,
    camera = (75, 40),
    markershape = :hexagon,
    markersize = 6,
    alpha = 0.8,
    legend = :none,
    colorbar = true,
    color = cgrad(:sun, rev = true),
    colorbar_title = "\n\n\n\nLoss of load expectation",
    ylabel = "N of wind turbines",
    ylabelfontsize = 8,
    zlabel = "Number of storage cells",
    zlabelfontsize = 8,
    left_margin = 2Plots.mm,
    right_margin = 8Plots.mm,
    bottom_margin = 5Plots.mm)
savefig(PlotLOLE, "C:/Users/Marcel/Desktop/mgr/graphs/LOLE.png")

PlotLOEE = scatter(
    string.(ResultsConstituentsAvg.iPVPanels),
    string.(ResultsConstituentsAvg.iTurbines),
    string.(ResultsConstituentsAvg.iStorageCells.+20),
    marker_z = ResultsConstituentsAvg.iLOEE,
    camera = (75, 40),
    markershape = :hexagon,
    markersize = 6,
    alpha = 0.8,
    legend = :none,
    colorbar = true,
    color = :sun,
    left_margin = 2Plots.mm,
    right_margin = 8Plots.mm,
    bottom_margin = 5Plots.mm,
    colorbar_title = "\n\n\n\nLoss of expected energy",
    ylabel = "N of wind turbines",
    ylabelfontsize = 8,
    zlabel = "Number of storage cells",
    zlabelfontsize = 8)
savefig(PlotLOEE, "C:/Users/Marcel/Desktop/mgr/graphs/LOEE.png")

PlotTotalConstituents = plot(
    PlotImpactsOfConsittuents, PlotLOLE, PlotLOEE,
    layout = (3,1),
    size = (1000, 800)
)
savefig(PlotTotalConstituents, "C:/Users/Marcel/Desktop/mgr/graphs/AllConstituents.png")

### Intended and realised actions ###
FinalEpisodeDetails = filter(row -> row.iEpisode == 40, ResultsConstituents)
t = groupby(FinalEpisodeDetails, [:iPVPanels, :iTurbines, :iStorageCells])

HistogramRealisedActions = histogram([t[i].iAction for i in 1:20], layout = (4,5),
    normalize = true,
    legend = false,
    xlim = (-0.2, 1.2),
    xlabel = "Action taken",
    xlabelfontsize = 6,
    xrotation = 90,
    ylim = (0,6),
    yticks = false,
    size = (1000, 800),
    titlefontsize = 10,
    color = RGB(192/255, 0, 0),
    left_margin = 2Plots.mm,
    right_margin = 2Plots.mm,
    bottom_margin = 2Plots.mm,
    top_margin = 2Plots.mm,
    title = [(unique(t[i].iPVPanels)[1], unique(t[i].iTurbines)[1], unique(t[i].iStorageCells.+20)[1]) for j in 1:1, i in 1:20])
savefig(HistogramRealisedActions, "C:/Users/Marcel/Desktop/mgr/graphs/HistogramRealisedActions.png")

HistogramIntendedAction = histogram([t[i].iIntendedAction for i in 1:20], layout = (4,5),
    normalize = true,
    legend = false,
    xlim = (-0.2, 1.2),
    xlabel = "Action intended",
    xlabelfontsize = 6,
    xrotation = 90,
    ylim = (0,6),
    yticks = false,
    size = (1000, 800),
    titlefontsize = 10,
    color = RGB(192/255, 0, 0),
    left_margin = 2Plots.mm,
    right_margin = 2Plots.mm,
    bottom_margin = 2Plots.mm,
    top_margin = 2Plots.mm,
    title = [(unique(t[i].iPVPanels)[1], unique(t[i].iTurbines)[1], unique(t[i].iStorageCells.+20)[1]) for j in 1:1, i in 1:20])
savefig(HistogramIntendedAction, "C:/Users/Marcel/Desktop/mgr/graphs/HistogramIntendedActions.png")

### Net loads plots ###
FinalEpisodeSingleConfigDetails = filter(row -> row.iStorageCells == 20,
    FinalEpisodeDetails)
insertcols!(FinalEpisodeSingleConfigDetails, :datapoint => repeat(collect(1:1:2183), 4))

PlotMismatch1 = @df filter(row -> row.iPVPanels == 600, FinalEpisodeSingleConfigDetails) StatsPlots.plot(
    :datapoint,
    :iMismatch,
    group = (:iTurbines),
    alpha = 0.5,
    size = (800,600),
    color = [RGB(192/255, 0, 0) RGB(100/255, 100/255, 100/255)],
    lw = 2,
    legendtitle = "Number of wind turbines",
    legendtitlefontsize = 8,
    legendfontsize = 6,
    xlabel = "Time step, testing period",
    xlabelfontsize = 6,
    ylabelfontsize = 6,
    ylabel = "Net load, [kWh]",
    title = "Net load change across testing period, number of PV panels = 600",
    titlefontsize = 12
)

PlotMismatch2 = @df filter(row -> row.iTurbines == 3, FinalEpisodeSingleConfigDetails) StatsPlots.plot(
    :datapoint,
    :iMismatch,
    group = (:iPVPanels),
    alpha = 0.5,
    size = (800,600),
    color = [RGB(192/255, 0, 0) RGB(100/255, 100/255, 100/255)],
    lw = 2,
    legendtitle = "Number of PV panels",
    legendtitlefontsize = 8,
    legendfontsize = 6,
    xlabelfontsize = 6,
    ylabelfontsize = 6,
    xlabel = "Time step, testing period",
    ylabel = "Net load, [kWh]",
    title = "Net load change across testing period, number of turbines = 3",
    titlefontsize = 12
)

PlotNetLoad = plot(PlotMismatch1, PlotMismatch2, layout = (2,1))
savefig(PlotNetLoad, "C:/Users/Marcel/Desktop/mgr/graphs/PlotNetLoad.png")
