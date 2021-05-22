using CSV, DataFrames, Dates, Distributions
using HypothesisTests, Random
using Plots, StatsBase, Turing
using FreqTables
using HTTP, LightXML
using MultivariateStats
cd("C:/Users/Marcel/Desktop/mgr/kody")
include("Households.jl")
cHouseholdsDir = "C:/Users/Marcel/Desktop/mgr/data/LdnHouseDataSplit"

Random.seed!(72945)

#########################################
####### Extract households data  ########
#########################################
HouseholdsData = GetHouseholdsData(cHouseholdsDir)

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
