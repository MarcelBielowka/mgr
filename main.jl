# add project and manifset?
# project.toml - dependencies expressed directly
# amnifest.toml - dependencies of dependencies
using Pipe: @pipe
using CSV, DataFrames, Dates, DataStructures, Distributions
using FreqTables, HypothesisTests
using MultivariateStats, Random
using StatsPlots, StatsBase
using Distributed
cd("C:/Users/Marcel/Desktop/mgr/kody")
include("Households.jl")
include("NonRefrigeratedStorage.jl")
include("ReadWeatherData.jl")
include("ReadPowerPricesData.jl")

#########################################
##### Setup for parallelisation  ########
#########################################
Distributed.nprocs()
Distributed.addprocs(8)
Distributed.nprocs()
Distributed.nworkers()
@everywhere include("NonRefrigeratedStorage.jl")

#########################################
######## Variables definition  ##########
#########################################
Random.seed!(72945)
cHouseholdsDir = "C:/Users/Marcel/Desktop/mgr/data/LdnHouseDataSplit"
cPowerPricesDataDir = "C://Users//Marcel//Desktop//mgr//data//POLPX_DA_20170101_20201014.csv"
cWindTempDataDir = "C:/Users/Marcel/Desktop/mgr/data/weather_data_temp_wind.csv"
cIrrDataDir = "C:/Users/Marcel/Desktop/mgr/data/weather_data_irr.csv"

@everywhere ArrivalsDict = zip(0:23,
    floor.([0, 0, 0, 0, 0, 0, 48, 28, 38, 48, 48, 48, 58, 68, 68, 68, 58, 48, 48, 38, 38, 16, 2, 0])) |> collect |> Dict
@everywhere DeparturesDict = zip(0:23,
    floor.([0, 0, 0, 0, 0, 0, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 0, 0])) |> collect |> Dict
@everywhere DistWeightCon = Distributions.Normal(1300, 200)
@everywhere DistInitFill = Distributions.Uniform(0.2, 0.5)
iStorageNumberOfSimulations = 100
iStorageSimWindow = 31
cWeatherPricesDataWindowStart = "2019-01-01"
cWeatherPricesDataWindowEnd = "2019-12-31"


#########################################
####### Extract households data #########
#########################################
HouseholdsData = GetHouseholdsData(cHouseholdsDir)

#########################################
####### Extract warehouse data  #########
#########################################
#@time WarehouseDataRaw = SimWrapper(iStorageNumberOfSimulations, iStorageSimWindow,
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict, false)
#WarehouseDataAggregated = ExtractFinalStorageData(WarehouseDataRaw)

#test1 = SimOneRun(3,1, DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict, true)
#test2 = SimOneRun(3,1, DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict, false)
#test5 = SimOneRun(3,3, DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict, false)

#test3 = SimWrapper(1, 1,
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict, true)
#test3 = SimWrapper(1, 1,
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict, false)

#test4 = SimWrapper(1, 1,
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict, false)


#a = fetch(@spawn SimOneRun(1,3, DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict))
#b = fetch(@spawn SimOneRun(2,3, DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict))

#a = fetch(@spawn test = SimOneRun(3,3, DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict, false))
#b = fetch(@spawn test2 = SimOneRun(3,3, DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict, false))
#@spawn test4 = SimOneRun(4,5, DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict, false)
@time a = pmap(RunMe,
    Base.Iterators.product(1:iStorageNumberOfSimulations, iStorageSimWindow, false))

#@distributed for i in 1:5
#    fetch(@spawn SimOneRun(i,3, DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict))
#end


#########################################
########### Extract weather data ########
#########################################
WeatherDataDetails = ReadWeatherData(cWindTempDataDir, cIrrDataDir,
    FilterStart = cWeatherPricesDataWindowStart,
    FilterEnd = cWeatherPricesDataWindowEnd)
dfWeatherData = WeatherDataDetails["dfFinalWeatherData"]
dfWindProduction = DataFrames.DataFrame(
    date = dfWeatherData.date,
    WindProduction = WindProductionForecast.(2, dfWeatherData.WindSpeed, 11.5, 3, 20)
)
# plot(dfWindProduction.date, dfWindProduction.WindProduction)
dfSolarProduction = DataFrames.DataFrame(
    date = dfWeatherData.date,
    SolarProduction = SolarProductionForecast.(0.45, dfWeatherData.Irradiation, dfWeatherData.Temperature,0.004, 45)
)
# plot(dfSolarProduction.date, dfSolarProduction.SolarProduction)

#########################################
######## Extract power prices data ######
#########################################
dfPowerPriceData = ReadPrices(cPowerPricesDataDir,
    DeliveryFilterStart = cWeatherPricesDataWindowStart,
    DeliveryFilterEnd = cWeatherPricesDataWindowEnd)

#########################################
####### Select days for simulation ######
#########################################
iDaysIndex = rand(1:Dates.value(FirstLastDay[2] - Dates.Date("2020-01-01")),
    Dates.value(FirstLastDay[2] - Dates.Date("2020-01-01")))
