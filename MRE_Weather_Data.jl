using CSV, DataFrames, Plots, Dates, Distributions, Random, StatsPlots
using HypothesisTests, RCall, Pipe, Statistics, Missings
using PyCall
st = pyimport("scipy.stats")

cd("C:/Users/Marcel/Desktop/mgr/kody")
include("WeatherDataFullPreparation.jl")

dfWeatherDataFull = ReadData()

dfWeatherDataFull.ClearnessIndex = ClearnessIndex.(
        dfWeatherDataFull.Irradiation, Dates.dayofyear.(dfWeatherDataFull.date_nohour),
        dfWeatherDataFull.hour, Dates.isleapyear.(dfWeatherDataFull.date_nohour)
    )

a = dfWeatherDataFull[dfWeatherDataFull.ClearnessIndex.>1,:]

# wiatr i temp dla 2019 r
