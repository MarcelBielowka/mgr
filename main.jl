using CSV, DataFrames, Dates, Distributions
using HypothesisTests, Random
using Plots, StatsBase, Turing
using FreqTables
using HTTP, LightXML
include("PriceModelling.jl")
include("Households.jl")
cd("C:/Users/Marcel/Desktop/mgr/kody")
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

AllDatesArray = Dates.Date("2020-01-01"):Dates.Day(1):Dates.Date("2020-10-14") |> collect
SelectedDatesArray = AllDatesArray[iDaysIndex]

abc = dfPriceDataFull[dfPriceDataFull.delivery_date.<SelectedDatesArray[2],:]

xyz = SplitDataPerHour(dfPriceDataFull, SelectedDatesArray[100], 360, 7)
SelectedDatesArray[1]-Dates.Day(365)

ADFTest(xyz[4]["log_price"], Symbol("constant"), 7)
ADFTest(diff(xyz[12]["log_price"]), Symbol("none"), 16)
ADFTest(xyz[11]["centred_log_price"], Symbol("none"), 7)
ADFTest(xyz[11]["log_load_forecast"], Symbol("squared_trend"), 16)
ADFTest(diff(xyz[11]["log_load_forecast"]), Symbol("squared_trend"), 16)
Turing.autocor(xyz[19]["log_price"])
autocor(a,lags = 7)

plot(xyz[20]["price"])

12*((365/100)^(1/4))

plot(xyz[20][:price])
plot(dfPriceDataFull[:delivery_date], dfPriceDataFull[:price])
xyz[20]
