# add project and manifset?
# project.toml - dependencies expressed directly
# amnifest.toml - dependencies of dependencies

#using JuliaInterpreter
#push!(JuliaInterpreter.compiled_modules, Base)
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
Distributed.addprocs(4)
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
dUKHolidayCalendar = Dates.Date.(["2013-01-01", "2013-03-29", "2013-04-01", "2013-05-06", "2013-05-27", "2013-08-26", "2013-12-25", "2013-12-26"])

@everywhere ArrivalsDict = zip(0:23,
    floor.([0, 0, 0, 0, 0, 0, 48, 28, 38, 48, 48, 48, 58, 68, 68, 68, 58, 48, 48, 38, 38, 16, 2, 0])) |> collect |> Dict
@everywhere DeparturesDict = zip(0:23,
    floor.([0, 0, 0, 0, 0, 0, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 0, 0])) |> collect |> Dict
@everywhere DistWeightCon = Distributions.Normal(1300, 200)
@everywhere DistInitFill = Distributions.Uniform(0.2, 0.5)
iWarehouseNumberOfSimulations = 100
iWarehouseSimWindow = 31
cWeatherPricesDataWindowStart = "2019-01-01"
cWeatherPricesDataWindowEnd = "2019-12-31"























#########################################
####### Extract households data #########
#########################################
HouseholdsData = GetHouseholdsData(cHouseholdsDir, dUKHolidayCalendar)
HouseholdsData["HouseholdProfiles"][(11,2)]
DataFrame(Hour = HouseholdsData["HouseholdProfiles"][(2,6)][:,1],
    AverageProfile = @pipe HouseholdsData["HouseholdProfiles"][(2,6)][:,2:3] |>
    Matrix(_) |>
    mean(_, weights(HouseholdsData["ClusteringCounts"][(2,6)]), dims = 2) |> _[:,1]
)
HouseholdsData["HouseholdProfilesWeighted"][(5,3)]
test = deepcopy(HouseholdsData["HouseholdProfilesWeighted"])

[test[(i,j)].ProfileWeighted .*=100 for i in 1:12, j in 1:7]
test[(5,3)]

HouseholdsData["HouseholdProfiles"][(11,2)][:,2:3]
HouseholdsData["ClusteringCounts"][(11,2)]
#########################################
####### Extract warehouse data  #########
#########################################
@time WarehouseDataRaw = pmap(SimWrapper,
    Base.Iterators.product(1:iWarehouseNumberOfSimulations, iWarehouseSimWindow, false))
WarehouseDataAggregated = ExtractFinalStorageData(WarehouseDataRaw)


#########################################
########### Extract weather data ########
#########################################
WeatherDataDetails = ReadWeatherData(cWindTempDataDir, cIrrDataDir,
    FilterStart = cWeatherPricesDataWindowStart,
    FilterEnd = cWeatherPricesDataWindowEnd)
dfWeatherData = WeatherDataDetails["dfFinalWeatherData"]
dfWindProduction = DataFrames.DataFrame(
    date = dfWeatherData.date,
    WindProduction = WindProductionForecast.(2000, dfWeatherData.WindSpeed, 11.5, 3, 20)
)
# Calculating the number of solar panels
# width - 51 slots in the warehouse * 1.4m width of the slot / 2.274m width of the panel
# length - 45 slots in the warehouse * 1.4m width of the slot / 3.134m length of the panel + spacing
# plot(dfWindProduction.date, dfWindProduction.WindProduction)
dfSolarProduction = DataFrames.DataFrame(
    date = dfWeatherData.date,
    SolarProduction = SolarProductionForecast.(0.55, dfWeatherData.Irradiation,
        dfWeatherData.Temperature, 0.0035, 45)
)
test = deepcopy(dfSolarProduction)
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
