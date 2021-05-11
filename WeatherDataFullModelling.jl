using Dates, RCall, StatsPlots, Distributions, Pipe, HypothesisTests
using ARCHModels, GLM
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

HypothesisTests.ADFTest(dfWindTempData.WindSpeed, :constant, 1000)
HypothesisTests.ADFTest(diff(dfWindTempData.Temperature), :trend, 168*2)

MayData = filter(row -> (row.month .== 5 && row.year == 2019), dfWindTempData)
NovData = filter(row -> (row.month .== 11 && row.year == 2019), dfWindTempData)
MayWeekData = filter(row -> (row.date >= Dates.Date("2019-05-01") && row.date <= Dates.Date("2019-05-07")), dfWindTempData)
NovWeekData = filter(row -> (row.date >= Dates.Date("2019-11-01") && row.date <= Dates.Date("2019-11-07")), dfWindTempData)

plot1Wind = plot(MayData.date, MayData.WindSpeed, title = "Wind speed series across May 2019", legend = nothing)
plot2Wind = plot(NovData.date, NovData.WindSpeed, title = "Wind speed series across November 2019", legend = nothing)
plot(plot1Wind, plot2Wind, layout = (2,1))

plot1Temp = plot(MayData.date, MayData.Temperature, title = "Temperature series across May")
plot2Temp = plot(NovData.date, NovData.Temperature, title = "Temperature series across November")
plot(plot1Temp, plot2Temp, layout = (2,1))

plot1WindWeekly = plot(MayWeekData.date, MayWeekData.WindSpeed, title = "Wind speed, 1st week May 2019", legend = nothing)
plot2WindWeekly = plot(NovWeekData.date, NovWeekData.WindSpeed, title = "Wind speed, 1st week November 2019", legend = nothing)
plot(plot1WindWeekly, plot2WindWeekly, layout = (2,1))

plot1TempWeekly = plot(MayWeekData.date, MayWeekData.Temperature, title = "Temperature, 1st week May 2019", legend = nothing)
plot2TempWeekly = plot(NovWeekData.date, NovWeekData.Temperature, title = "Temperature, 1st week November 2019", legend = nothing)
plot(plot1TempWeekly, plot2TempWeekly, layout = (2,1))


FirstModel = ARCHModels.fit(ARMA{1,1}, dfWindTempData.WindSpeed)
spec = ARCH{0}([0.3])
myData = dfWindTempData.WindSpeed
model = UnivariateARCHModel(ARCH{0}([0.0]), dfWindTempData.WindSpeed, meanspec = ARMA{1,1}(zeros(3)))
testModel = R"arima"(dfWindTempData.WindSpeed, order = R"c(1,0,1)")
prediction = R"predict"(testModel)
abc =
t = fit(model)
testModel[9]
p = ARMA{1,1}([0.5, 0.3, 0.4])
z = fit(p, dfWindTempData.WindSpeed)

predict(t, :return)
dfWindTempData.WindSpeed
