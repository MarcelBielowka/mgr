using Dates, RCall, StatsPlots, Distributions, Pipe
@rlibrary MASS
using PyCall, Conda
Conda.add("scipy")
st = pyimport("scipy.stats")

#dfWeatherDataGrouped[7]

include("WeatherDataFullPreparation.jl")
dfWeatherDataUngrouped = ReadData()
dfWeatherDataUngrouped.ClearnessIndex = ClearnessIndex.(
    dfWeatherDataUngrouped.Irradiation, Dates.dayofyear.(dfWeatherDataUngrouped.date_nohour),
    dfWeatherDataUngrouped.hour, Dates.isleapyear.(dfWeatherDataUngrouped.date_nohour),
    LimitAtOne
)

dfWeatherDataGrouped = RetrieveGroupedData(dfWeatherDataUngrouped)

TestFitIndex = st.beta.fit(dfWeatherDataGrouped[7].ClearnessIndex)
TestFitIrradiation = st.beta.fit(dfWeatherDataGrouped[7].Irradiation)
TestFitWindSpeed = st.weibull_min.fit(dfWeatherDataGrouped[7].WindSpeed)
DistIndex = Distributions.Beta(TestFitIndex[1], TestFitIndex[2])
DistIrradiation = Distributions.Beta(TestFitIrradiation[1], TestFitIrradiation[2])
DistWindSpeed = Distributions.Weibull(TestFitWindSpeed[1], TestFitWindSpeed[3])
(dfWeatherDataGrouped[7] |> DataFrame).ClearnessIndex

StatsPlots.histogram(dfWeatherDataGrouped[8].ClearnessIndex./1.14, normalize = true)
plot!(ccc,lw = 5, color =:red)
plot(
 qqplot(ccc, (dfWeatherDataGrouped[8] |> DataFrame).ClearnessIndex ./18.2)
)

StatsPlots.histogram(dfWeatherDataGrouped[7].WindSpeed, normalize = true)
plot!(ddd,lw = 5, color =:red)
plot(
 qqplot(ddd, (dfWeatherDataGrouped[7] |> DataFrame).WindSpeed.+0.826)
)
