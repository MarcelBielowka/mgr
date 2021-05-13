using Dates, RCall, StatsPlots, Distributions, Pipe, HypothesisTests
using ARCHModels, GLM
#@rlibrary MASS
#@rlibrary forecast

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
HypothesisTests.ADFTest((dfWindTempData.Temperature), :trend, 168*2)
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

dfWindTempTrainData = filter(row -> (row.date>=Dates.Date("2018-01-01") && row.date<= Dates.DateTime("2018-10-31T23:50")), dfWindTempData)
dfWindTempTestData = filter(row -> (row.date>=Dates.Date("2018-11-01") && row.date<= Dates.DateTime("2018-12-31T23:50")), dfWindTempData)
dfWindTempEstimationData = filter(row -> row.year == 2018, dfWindTempData)
dfWindTempValidationData = filter(row -> row.year == 2017, dfWindTempData)
dfWindTempRealisedData = filter(row -> row.year == 2019, dfWindTempData)

outputDF = DataFrame(p=[], q=[], RMSE = [], aic = [])
function FindBestModel(data, maxp, maxq)
    outputDF = DataFrame(p=[], q=[], aic = [])
    for p in 0:maxp, q in 0:maxq
        println("Fitting model ARMA($p, $q)")
        myModelInitSpec = UnivariateARCHModel(ARCH{0}([0.0]), dfWindTempTrainData.WindSpeed, meanspec = ARMA{p,q}(zeros(p+q+1)))
        myModel = fit(myModelInitSpec)
        push!(outputDF, (p, q, aic(myModel)))
        #println("Fitting model ARMA($p, $q)")
        #fittedModel = fit(model)
        #push!(outputDF, (p,q,aic(fittedModel)))
    end
    return outputDF
end

@time outputDF = FindBestModel(dfWindTempTrainData.WindSpeed, 8, 8)
outputDF

p = 0; q = 1
[]

myModelInitSpec = UnivariateARCHModel(ARCH{0}([0.0]),
    dfWindTempEstimationData.WindSpeed[dfWindTempEstimationData.date .< Dates.DateTime("2018-11-01")],
    meanspec = ARMA{1,3}(zeros(5)))
myModel = fit(myModelInitSpec)
predict.(myModel, :return, 1:3)
testDAta = deepcopy(dfWindTempEstimationData[dfWindTempEstimationData.date .< Dates.DateTime("2018-11-01"),:])
select!(testDAta, [:date, :WindSpeed])
push!(testDAta, (testDAta.date[size(testDAta)[1]] + Dates.Hour(1), predict(myModel, :return, 1)))
myModel.meanspec.coefs
aic(myModel)
bic(myModel)


testModel = R"forecast::Arima"(dfWindTempTrainData.WindSpeed, order = R"c(8,0,3)", method = "ML")
abc = R"forecast::Arima"(dfWindTempTestData.WindSpeed, model = testModel)
a = R"forecast::accuracy"(abc)
Forecast = R"forecast::forecast"(testModel, h = 24, dfWindTempTestData.WindSpeed)
R"forecast::accuracy"(Forecast)

testModel = R"forecast::Arima"(dfWindTempTrainData.WindSpeed, order = R"c(2,0,1)", method = "ML")
Forecast2 = R"forecast::forecast"(testModel, h = 24, dfWindTempTestData.WindSpeed)
R"forecast::accuracy"(Forecast2)

Forecast2[1]

testModel[1]
testModel[5]
testModel[6][1]
prediction = R"predict"(testModel)
testModel[9]
p = ARMA{1,1}([0.5, 0.3, 0.4])

predict(t, :return)
dfWindTempData.WindSpeed
