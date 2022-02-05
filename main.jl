# add project and manifset?
# project.toml - dependencies expressed directly
# amnifest.toml - dependencies of dependencies

using JuliaInterpreter
push!(JuliaInterpreter.compiled_modules, Base)
using Pipe: @pipe
using CSV, DataFrames, Dates, DataStructures, Distributions
using FreqTables, HypothesisTests
using MultivariateStats, Random
using StatsPlots, StatsBase
using Flux
using Distributed
cd("C:/Users/Marcel/Desktop/mgr/kody")
include("Households.jl")
include("DefineMainClasses.jl")
include("NonRefrigeratedStorage.jl")
include("ReadWeatherData.jl")
include("ReadPowerPricesData.jl")
include("DefineRL.jl")

#########################################
##### Static variables definition  ######
#########################################
Random.seed!(72945)
cHouseholdsDir = "C:/Users/Marcel/Desktop/mgr/data/LdnHouseDataSplit"
cPowerPricesDataDir = "C://Users//Marcel//Desktop//mgr//data//POLPX_DA_all.csv"
cWindTempDataDir = "C:/Users/Marcel/Desktop/mgr/data/weather_data_temp_wind.csv"
cIrrDataDir = "C:/Users/Marcel/Desktop/mgr/data/weather_data_irr.csv"
dUKHolidayCalendar = Dates.Date.(["2013-01-01", "2013-03-29", "2013-04-01", "2013-05-06", "2013-05-27", "2013-08-26", "2013-12-25", "2013-12-26"])
dPLHolidayCalendar = Dates.Date.(["2019-01-01", "2019-04-22", "2019-05-01", "2019-05-03", "2019-06-20", "2019-08-15", "2019-11-01", "2019-11-11", "2019-12-25", "2019-12-26"])
iWarehouseNumberOfSimulations = 100
iWarehouseSimWindow = 40
iMicrogridPrice = 200.0
cWeatherPricesDataWindowStart = "2019-01-01"
cWeatherPricesDataWindowEnd = "2019-12-31"

dRunStartTrain = @pipe Dates.Date("2019-04-01") |> Dates.dayofyear |> _*24 |> _- 23
dRunEndTrain = @pipe Dates.Date("2019-09-30") |> Dates.dayofyear |> _*24 |> _-1
dRunStartTest = dRunEndTrain + 1
dRunEndTest = @pipe Dates.Date("2019-12-30") |> Dates.dayofyear |> _*24 |> _-1
iEpisodeLength = dRunStartTest - dRunEndTest |> abs
iEpisodeLengthTrain = dRunStartTrain - dRunEndTrain |> abs

#########################################
##### Setup for parallelisation  ########
#########################################
Distributed.nprocs()
Distributed.addprocs(4)
Distributed.nprocs()
Distributed.nworkers()
@everywhere include("NonRefrigeratedStorage.jl")
@everywhere ArrivalsDict = zip(0:23,
    floor.([0, 0, 0, 0, 0, 0, 48, 28, 38, 48, 48, 48, 58, 68, 68, 68, 58, 48, 48, 38, 38, 16, 2, 0] .* 2)) |> collect |> Dict
@everywhere DeparturesDict = zip(0:23,
    floor.([0, 0, 0, 0, 0, 0, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 0, 0] .* 2)) |> collect |> Dict
@everywhere DistWeightCon = Distributions.Normal(1300, 200)
@everywhere DistInitFill = Distributions.Uniform(0.2, 0.5)

#########################################
## Classes definition, data extraction ##
#########################################
####
# Power prices data
####
DayAheadPowerPrices = GetDayAheadPricesHandler(cPowerPricesDataDir,
    cWeatherPricesDataWindowStart,
    cWeatherPricesDataWindowEnd)

####
# Weather data
####
Weather = GetWeatherDataHandler(cWindTempDataDir, cIrrDataDir,
    cWeatherPricesDataWindowStart, cWeatherPricesDataWindowEnd)

####
# Initiate the wind park
####
MyWindPark = GetWindPark(2000.0, 11.5, 3.0, 20.0, Weather, 3)

####
# Initiate the households
####
Households = Get_⌂(cHouseholdsDir, dUKHolidayCalendar, dPLHolidayCalendar,
    cWeatherPricesDataWindowStart, cWeatherPricesDataWindowEnd,
    100, 13.5, 7.0, -5.0, 20)
# TestHouseholds = deepcopy(Households)
Households.dictHouseholdsData = Dict()
#Households.EnergyConsumption[(12,6)]

####
# Initiate the warehouse
####
#MyWarehouse = GetWarehouse(iWarehouseNumberOfSimulations, iWarehouseSimWindow, 2, 2019, 0.1, 20.0,
#    0.55, 0.0035, 45, 300, Weather, 11.7, 1.5*11.75, 0.5*11.7, 10)
#CSV.write("C:/Users/Marcel/Desktop/mgr/data/WarehouseEnergyConsumption.csv", MyWarehouse.dfEnergyConsumption)
#CSV.write("C:/Users/Marcel/Desktop/mgr/data/ConsignmentHist.csv", MyWarehouse.dfConsignmentHistory)
# Calculating the number of solar panels
# width - 51 slots in the warehouse * 1.4m width of the slot / 2.274m width of the panel
# length - 45 slots in the warehouse * 1.4m width of the slot / 3.134m length of the panel + spacing

dfRawEnergyConsumption = CSV.File("C:/Users/Marcel/Desktop/mgr/data/WarehouseEnergyConsumption.csv") |> DataFrame
dfRawConsHistory = CSV.File("C:/Users/Marcel/Desktop/mgr/data/ConsignmentHist.csv") |> DataFrame
MyWarehouse = GetTestWarehouse(dfRawEnergyConsumption, dfRawConsHistory, 2, 2019, 0.1, 20.0,
    0.55, 0.0035, 45, 600, Weather, 13.5, 7.0, -5.0, 20)

#########################################
##### Learning process - tuning #########
#########################################
### Tuning the episode length ###
TuningEpisodesLength = @time FineTuneTheMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households,
    ["identity"], [25, 50, 75, 100],
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [2], [0.5], [0.999],
    [0.0001], [0.0001],
    [100], [100])
EpisodesLengthAug = GetDataForPlottingFromResultsHolder(TuningEpisodesLength)

### Tuning β ###
TuningBeta = @time FineTuneTheMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households,
    ["identity"], [40],
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [2], [0.5], [0.99, 0.995, 0.999, 1.0],
    [0.0001], [0.0001],
    [100], [100])
BetaParamsAug = GetDataForPlottingFromResultsHolder(TuningBeta)

### Tuning commercial params ###
TuningCommercialParams = @time FineTuneTheMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households,
    ["identity"], [40],
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [0, 2, 6, 12, 24], [0.9, 0.7, 0.5, 0.3], [0.999],
    [0.0001], [0.0001],
    [100], [100])
CommercialParamsAug = GetDataForPlottingFromResultsHolder(TuningCommercialParams)

### Tuning neural network hyperparams ###
TuningNNParams = @time FineTuneTheMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households,
    ["identity"], [40],
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [2], [0.7], [0.999],
    [0.0001, 0.001], [0.0001, 0.001],
    [50, 100, 200], [50, 100, 200])
NNParamsAug = GetDataForPlottingFromResultsHolder(TuningNNParams)

#########################################
######## Members sensitibity ############
#########################################
MembersTuning = FineTuneMembers(DayAheadPowerPrices, Weather,
    2000.0, 11.5, 3.0, 20.0,
    [3, 5],
    dfRawEnergyConsumption, dfRawConsHistory, 2, 2019, 0.1, 20.0,
    0.55, 0.0035, 45, [600, 1200],
    13.5, 7.0, -5.0, [20, 60, 100, 140, 180],
    Households,
    ["identity"], [40],
    dRunStartTrain, dRunEndTrain, dRunStartTest, dRunEndTest,
    [2], [0.7], [0.999],
    [0.0001], [0.0001],
    [100], [100])
ResultsConstituents = GetResultsFromMembersResultsHolder(MembersTuning, 40, 4390, 2183)
