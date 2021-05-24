using Pipe: @pipe
using CSV, DataFrames, Dates, DataStructures, Distributions
using FreqTables, HypothesisTests
using MultivariateStats, Random
using StatsPlots, StatsBase
using HTTP, LightXML
cd("C:/Users/Marcel/Desktop/mgr/kody")
include("Households.jl")
include("NonRefrigeratedStorage.jl")
include("ReadWeatherAndPriceData.jl")

#########################################
######## Variables definition  ##########
#########################################
Random.seed!(72945)
cHouseholdsDir = "C:/Users/Marcel/Desktop/mgr/data/LdnHouseDataSplit"
ArrivalsDict = zip(0:23,
    floor.([0, 0, 0, 0, 0, 0, 48, 28, 38, 48, 48, 48, 58, 68, 68, 68, 58, 48, 48, 38, 38, 16, 2, 0])) |> collect |> Dict
DeparturesDict = zip(0:23,
    floor.([0, 0, 0, 0, 0, 0, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 0, 0])) |> collect |> Dict
DistWeightCon = Distributions.Normal(1300, 200)
DistInitFill = Distributions.Uniform(0.2, 0.5)
iStorageNumberOfSimulations = 100
iStorageSimWindow = 31


#########################################
####### Extract households data  ########
#########################################
HouseholdsData = GetHouseholdsData(cHouseholdsDir)

#########################################
####### Extract warehouse data  #########
#########################################
@time WarehouseDataRaw = SimWrapper(iStorageNumberOfSimulations, iStorageSimWindow,
        45, 51, 7, 1.4, 1.4, 0.8,
        1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||", 20, 60, 150,
        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)
WarehouseDataAggregated = ExtractFinalStorageData(WarehouseDataRaw)

#########################################
###### Extract price and load data  #####
#########################################
cPriceDataDir = "C://Users//Marcel//Desktop//mgr//data//POLPX_DA_20170101_20201014.csv"
dfPriceDataFull = ReadPrices(cPriceDataDir)
FirstLastDay = extrema(dfPriceDataFull.delivery_date)
string(year(FirstLastDay[2]))*"-01-01" |> Date

#########################################
####### Select days for simulation ######
#########################################
iDaysIndex = rand(1:Dates.value(FirstLastDay[2] - Dates.Date("2020-01-01")),
    Dates.value(FirstLastDay[2] - Dates.Date("2020-01-01")))
