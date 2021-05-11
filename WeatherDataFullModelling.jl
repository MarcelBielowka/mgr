using Dates, RCall, StatsPlots, Distributions, Pipe, HypothesisTests
@rlibrary MASS
@rlibrary tseries

include("WeatherDataFullPreparation.jl")

dfWindTempDataRaw = ReadWindAndTempData("C:/Users/Marcel/Desktop/mgr/data/weather_data_temp_wind.csv")
WindTempDataCleanUp = RemedyMissingWindTempData(dfWindTempDataRaw)
dfWindTempData = WindTempDataCleanUp["WindTempDataNoMissing"]

filter!(row -> row.date >= Dates.DateTime("2017-01-01"), dfWindTempData)

R"pacf"(dfWindTempData.WindSpeed)
R"acf"(dfWindTempData.WindSpeed)
R"pacf"(dfWindTempData.Temperature)
R"acf"(dfWindTempData.Temperature)

plot(dfWindTempData.date, dfWindTempData.WindSpeed, title = "Wind speed")
plot(dfWindTempData.date, dfWindTempData.Temperature, title = "Temperature")

HypothesisTests.ADFTest(dfWindTempData.WindSpeed, :constant, 24)
HypothesisTests.ADFTest(dfWindTempData.Temperature, :squared_trend, 365)

MayData = filter(row -> (row.month .== 5 && row.year == 2019), dfWindTempData)
NovData = filter(row -> (row.month .== 11 && row.year == 2019), dfWindTempData)

plot1Wind = plot(MayData.date, MayData.WindSpeed, title = "Wind speed series across May")
plot2Wind = plot(NovData.date, NovData.WindSpeed, title = "Wind speed series across November")
plot(plot1Wind, plot2Wind, layout = (2,1))

plot1Temp = plot(MayData.date, MayData.Temperature, title = "Temperature series across May")
plot2Temp = plot(NovData.date, NovData.Temperature, title = "Temperature series across November")
plot(plot1Temp, plot2Temp, layout = (2,1))
