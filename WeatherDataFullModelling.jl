using Dates, RCall, StatsPlots, Distributions, Pipe
@rlibrary MASS

include("WeatherDataFullPreparation.jl")

dfWeatherData = ReadData()
dfWeatherData.Temperature = dfWeatherData.Temperature .+ 273.15
dfWeatherData.MonthPart =
    Dates.day.(dfWeatherData.date_nohour) .> Dates.daysinmonth.(dfWeatherData.date_nohour)/2

dfWeatherDataGrouped = groupby(dfWeatherData, [:month, :MonthPart])

GroupsMapping = sort(dfWeatherDataGrouped.keymap, by = values)
GroupsMapping.vals[1]
GroupsMapping.keys

WeatherDistParameters = Dict{}()
month, monthperiod = GroupsMapping.keys[1]

m = dfWeatherDataGrouped[1]
m_subs = m[m.hour .== 14, :]
a = fitdistr(m_subs.WindSpeed[m_subs.WindSpeed.>0], "weibull", lower = "c(0,0)")

for PeriodNum in 1:24
    CurrentPeriod = GroupsMapping.vals[PeriodNum]
    dfCurrentPeriod = dfWeatherDataGrouped[CurrentPeriod]
    month, MonthPeriod = GroupsMapping.keys[PeriodNum]

    for hour in extrema(dfWeatherDataGrouped[1].hour)[1]:extrema(dfWeatherDataGrouped[1].hour)[2]
        dfCurrentHour = filter(row -> row.hour .== hour, dfCurrentPeriod)
        println("Current month: $month, period: $PeriodNum , hour: $hour")

        DistWindMASS = fitdistr(dfCurrentHour.WindSpeed[dfCurrentHour.WindSpeed.>0], "weibull", lower = R"c(0,0)")
        DistSolarMASS = fitdistr(dfCurrentHour.Irradiation, "normal")
        DistTempMASS = fitdistr(dfCurrentHour.Temperature, "normal")

        push!(WeatherDistParameters, (month, MonthPeriod, hour) => ["WindParam" => [DistWindMASS[1][1] DistWindMASS[1][2]],
                                                                      "SolarParam" => [DistSolarMASS[1][1] DistSolarMASS[1][2]],
                                                                      "TempParam" => [DistTempMASS[1][1] DistTempMASS[1][2]],
                                                               ])
    end
end

temp = dfWeatherDataGrouped[22][dfWeatherDataGrouped[22].hour .== 18,:].WindSpeed
fitdistr(temp[temp.>0], "weibull", lower = R"c(0,0)")


DayOfYear = rand(1:365)

DateAnalysed = Date(2018,12,31) + Dates.Day(DayOfYear)
MonthPart = Dates.day.(DateAnalysed) .> Dates.daysinmonth.(DateAnalysed)/2

for hour in 0:23
    Weather = WeatherDistParameters[(Dates.month(DateAnalysed), MonthPart, hour)]
    println("$hour")
    println(Weather)
end

a = WeatherDistParameters[2, false, 1][1][2]
DistTemp = Weibull(WeatherDistParameters[1, true, 22][1][2][1], WeatherDistParameters[1, true, 22][1][2][2])
m = rand(DistTemp, 1000)
histogram(m, normalize = true)
plot!(DistTemp, lw = 5, color =:red)
p = mean(rand(DistTemp, 1000))
t = [mean(rand(DistTemp, 1000)) for i in 1:10000]
mean(t)
histogram(t, normalize = true)
plot!(Normal(mean(t), std(t)), lw = 3)

function WindProductionForecast(P_nam, V, V_nam, V_cutin, V_cutoff)
    if V < V_cutin
        P_output = 0
    elseif V >= V_cutin && V < V_nam
        P_output = ((V - V_cutin) ^ 3) / -((V_cutin - V_nam)^3) * P_nam
    elseif V >= V_nam && V < V_cutoff
        P_output = P_nam
    else
        P_output = 0
    end
    return P_output
end

ForecastWind = WindProductionForecast.(2.0, mean(t), 11.5, 3.0, 20.0)*10
mean(ForecastWind) * 10
histogram(ForecastWind, normalize = true)

(11.5 - 3) ^ 3 / -(3 - 11.5) ^ 3 * 2 * 10
