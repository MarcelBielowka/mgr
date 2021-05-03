using CSV, DataFrames, SplitApplyCombine
using Plots, Dates, Distributions, Random, StatsPlots
using HypothesisTests, RCall, PyCall
using Pipe, Statistics, Missings
using Impute
include("SolarAngle.jl")
st = pyimport("scipy.stats")
@rlibrary MASS

#using JuliaInterpreter
#push!(JuliaInterpreter.compiled_modules, Base)

## read and clean data

function CleanCAMSdata(dfData::DataFrame)
    rename!(dfData, ["Date", "TOA", "GHI", "BHI", "DHI", "BNI"])
    insertcols!(dfData, ([:date, :DateLocal] .=>
        invert(split.(dfData.Date, "/")))...,
                       makeunique=true)
    select!(dfData, [:date, :TOA, :GHI])
    dfData.date = Dates.DateTime.(dfData.date)
    return dfData
end

function ReadWindAndTempData(cFileWind::String)
    dfWindData = CSV.File(cFileWind) |>
        DataFrame
    select!(dfWindData, [:date, :temp_avg, :predkosc100m_avg])
    rename!(dfWindData, [:date, :Temperature, :WindSpeed])

    dfWindData["date"] =
        Dates.DateTime.(dfWindData.date, DateFormat("y-m-d H:M:S"))
    dfWindData.Temperature[dfWindData.Temperature .== "NA"] .= "Inf"
    dfWindData.Temperature = parse.(Float64, dfWindData.Temperature)

    allowmissing!(dfWindData)
    dfWindData.Temperature[dfWindData.Temperature .== Inf] .= missing
    dfWindData.WindSpeed[dfWindData.WindSpeed .== Inf] .= missing

    dfWindData["date_nohour"] = Dates.Date.(dfWindData["date"])
    dfWindData["month"] = Dates.month.(dfWindData["date"])
    dfWindData["hour"] = Dates.hour.(dfWindData["date"])
    dfWindData["year"] = Dates.year.(dfWindData["date"])

    return dfWindData
end

function RemedyMissingWindTempData(dfWindData)
    MissingWindData = filter(row -> ismissing(row.WindSpeed), dfWindData)
    MissingTempData = filter(row -> ismissing(row.Temperature), dfWindData)
    dfWindDataClean = dropmissing(dfWindData)
    return Dict(
        "MissingWindData" => MissingWindData,
        "MissingTempData" => MissingTempData,
        "WindTempDataNoMissing" => dfWindDataClean
    )
end

dfWindTempData = ReadWindAndTempData("C:/Users/Marcel/Desktop/mgr/data/weather_data_temp_wind.csv")
Redemption = RemedyMissingWindTempData(dfWindTempData)
GroupedMissingDataWind = @pipe groupby(Redemption["MissingWindData"], [:year, :month]) |>
    combine(_, nrow => :MissingCount)
GroupedMissingDataTemp = @pipe groupby(Redemption["MissingTempData"], [:year, :month]) |>
    combine(_, nrow => :MissingCount)
dfWindTempDataFinal = Redemption["WindTempDataNoMissing"]

function ReadIrradiationData(cFileIrr::String, cFileTheoretical::String)
    dfWeatherData = CSV.File(cFileIrr) |>
        DataFrame
    select!(dfWeatherData, [:date, :prom_avg])
    dfWeatherData.date = Dates.DateTime.(dfWeatherData.date, DateFormat("y-m-d H:M:S"))

    dfWeatherDataTempTheoretical = CSV.File(cFileTheoretical,
        delim = ";", header = 38) |>
        DataFrame
    dfWeatherDataTempTheoretical = CleanCAMSdata(dfWeatherDataTempTheoretical)

    dfWeatherData = DataFrames.innerjoin(dfWeatherData, dfWeatherDataTempTheoretical, on = :date )
    rename!(dfWeatherData, ["date", "Irradiation", "TOA", "GHI"])

    dfWeatherData.Irradiation[dfWeatherData.Irradiation .== "NA"] .= "Inf"
    dfWeatherData.Irradiation = parse.(Float64, dfWeatherData.Irradiation)
    allowmissing!(dfWeatherData)
    dfWeatherData.Irradiation[dfWeatherData.Irradiation .== Inf] .= missing

    dfWeatherData["date_nohour"] = Dates.Date.(dfWeatherData["date"])
    dfWeatherData["month"] = Dates.month.(dfWeatherData["date"])
    dfWeatherData["hour"] = Dates.hour.(dfWeatherData["date"])
    dfWeatherData["year"] = Dates.year.(dfWeatherData["date"])

    return dfWeatherData
end

function RemedyMissingIrradiationData(dfIrrData)
    dfMissingIrradiationData = filter(row -> ismissing(row.Irradiation), dfIrrData)
    GroupedMissingIrradiationData = @pipe groupby(dfMissingIrradiationData, [:year, :month]) |>
            combine(_, nrow => :MissingCount)
    dfOutputData = dropmissing(dfIrrData)
    return Dict(
        "AggregatedMissingIrradiationData" => GroupedMissingIrradiationData,
        "UnitMissingIrradiationData" => dfMissingIrradiationData,
        "IrradiationDataNoMissing" => dfOutputData
    )

end

function CalculateIndex(dfIrrData)
    dfIrrData[:SunPosition] = SunPosition.(dfIrrData.year,
                                               dfIrrData.month,
                                               Dates.day.(dfIrrData.date),
                                               dfIrrData.hour
    )

    dfIrrData.Irradiation[dfIrrData.SunPosition .< 10] .= 0
    dfIrrData[:ClearSkyIndex] = zeros(size(dfIrrData)[1])
    dfIrrData[:ClearnessIndex] = zeros(size(dfIrrData)[1])

    dfIrrData.ClearSkyIndex[dfIrrData.Irradiation .> 0] =
        dfIrrData.Irradiation[dfIrrData.Irradiation .> 0] ./
        dfIrrData.GHI[dfIrrData.Irradiation .> 0]

    dfIrrData.ClearnessIndex[dfIrrData.Irradiation .> 0] =
        dfIrrData.Irradiation[dfIrrData.Irradiation .> 0] ./
        dfIrrData.TOA[dfIrrData.Irradiation .> 0]

    return dfIrrData
end

dfIrradiationData = ReadIrradiationData("C:/Users/Marcel/Desktop/mgr/data/weather_data_irr.csv",
                        "C:/Users/Marcel/Desktop/mgr/data/clear_sky_irradiation_CAMS.csv")
dfIrradiationData = RemedyMissingIrradiationData(dfIrradiationData)["IrradiationDataNoMissing"]
dfIrradiationData = CalculateIndex(dfIrradiationData)



## Grouping data for modelling purposes

function WindTempDistributions(dfWeatherData; kelvins::Bool = true)
    dfData = deepcopy(dfWeatherData)
    if kelvins
        dfData.Temperature = dfData.Temperature .+ 273.15
    end

    dfData.MonthPart =
        Dates.day.(dfData.date_nohour) .> Dates.daysinmonth.(dfData.date_nohour)/2
    dfDataGrouped = groupby(dfData, [:month, :MonthPart])
    GroupsMapping = sort(dfDataGrouped.keymap, by = values)
    dfWeatherDistParameters = DataFrame(month = [], MonthPeriod = [], hour = [],
                                      DistWind = [], DistTemp = [],
                                      PValueCvMTestWind = [], PValueCvMTestTemp = [],
                                      ZeroWindSpeedRatio = [])

    for PeriodNum in 1:24
        CurrentPeriod = GroupsMapping.vals[PeriodNum]
        dfCurrentPeriod = dfDataGrouped[CurrentPeriod]
        month, MonthPeriod = GroupsMapping.keys[PeriodNum]

        for hour in 0:23
            dfCurrentHour = filter(row -> row.hour .== hour, dfCurrentPeriod)
            println("Current month: $month, period: $PeriodNum , hour: $hour")
            DistWind = st.weibull_min.fit(dfCurrentHour.WindSpeed)
            DistTemp = st.norm.fit(dfCurrentHour.Temperature)
            PValueCvMTestWind = st.cramervonmises(
                    dfCurrentHour.WindSpeed, "weibull_min", args = (DistWind)
                ).pvalue
            PValueCvMTestTemp = st.cramervonmises(
                dfCurrentHour.Temperature, "norm", args = (DistTemp)
            ).pvalue
            ZeroWindSpeedRatio = length(dfCurrentHour.WindSpeed[dfCurrentHour.WindSpeed.==0]) / length(dfCurrentHour.WindSpeed)

            push!(dfWeatherDistParameters, (month, MonthPeriod, hour,
                                            DistWind, DistTemp,
                                            PValueCvMTestWind, PValueCvMTestTemp,
                                            ZeroWindSpeedRatio
                                            )
                )
        end
    end

    return Dict(
        "dfWeatherDistParameters" => dfWeatherDistParameters,
        "dfDataGrouped" => dfDataGrouped
    )
end

a = Juno.@enter WindTempDistributions(dfWindTempDataFinal)
a = WindTempDistributions(dfWindTempDataFinal)
a["dfWeatherDistParameters"]
a["dfDataGrouped"]

t = ExactOneSampleKSTest(filter(row -> row.hour == 12, a["dfDataGrouped"][1]).Temperature,
    Normal(
        a["WeatherDistParameters"][1, false, 12]["TempMean"],
        a["WeatherDistParameters"][1, false, 12]["TempStd"]
    ))
pvalue(t)
histogram(filter(row -> row.hour == 12, a["dfDataGrouped"][1]).Temperature, normalize = true)
a["WeatherDistParameters"][1, false, 12]
plot!(Normal(
        a["WeatherDistParameters"][1, false, 12]["TempMean"],
        a["WeatherDistParameters"][1, false, 12]["TempStd"]
    ), lw = 3)

histogram(filter(row -> row.hour == 9, a["dfDataGrouped"][6]).WindSpeed, normalize = true)
a["WeatherDistParameters"][3, true, 9]
plot!(Weibull(
        a["WeatherDistParameters"][3, true, 9]["WindMean"],
        a["WeatherDistParameters"][3, true, 9]["WindStd"]
    ), lw = 3)


function IrradiationDistributions(dfWeatherData)
    dfData = deepcopy(dfWeatherData)
    dfData.MonthPart =
        Dates.day.(dfData.date_nohour) .> Dates.daysinmonth.(dfData.date_nohour)/2
    dfDataGrouped = groupby(dfData, [:month, :MonthPart])
    GroupsMapping = sort(dfDataGrouped.keymap, by = values)
    dfWeatherDistParameters = DataFrame(month = [], MonthPeriod = [], hour = [],
                                        DistClearSky = [], DistClearness = [],
                                        PValueCvMTestClearSky = [],
                                        PValueCvMTestClearness = [],
                                        ratioClearSky = [],
                                        ratioClearness = [])

    for PeriodNum in 1:24
        CurrentPeriod = GroupsMapping.vals[PeriodNum]
        dfCurrentPeriod = dfDataGrouped[CurrentPeriod]
        month, MonthPeriod = GroupsMapping.keys[PeriodNum]

        for hour in 0:23
            dfCurrentHour = filter(row -> row.hour .== hour, dfCurrentPeriod)
            ratioClearSky = size(dfCurrentHour[dfCurrentHour.ClearSkyIndex.>0, :])[1] / size(dfCurrentHour)[1]
            ratioClearness = size(dfCurrentHour[dfCurrentHour.ClearnessIndex.>0, :])[1] / size(dfCurrentHour)[1]
            println("Current month: $month, period: $PeriodNum , hour: $hour")
            println("Ratio of 0 Clear Sky index to all data is $ratioClearSky and of Clearness index is $ratioClearness")
            if ratioClearSky < 0.5
                DistClearSky = nothing
                PValueCvMTestClearSky = nothing
            else
                DistClearSky = st.beta.fit(dfCurrentHour.ClearSkyIndex)
                PValueCvMTestClearSky = st.cramervonmises(
                    dfCurrentHour.ClearSkyIndex, "beta", args = (DistClearSky)
                ).pvalue
            end

            if ratioClearness < 0.5
                DistClearness = nothing
                PValueCvMTestClearness = nothing
            else
                DistClearness = st.beta.fit(dfCurrentHour.ClearnessIndex)
                PValueCvMTestClearness = st.cramervonmises(
                    dfCurrentHour.ClearnessIndex, "beta", args = (DistClearness)
                ).pvalue
            end
            push!(dfWeatherDistParameters, (month, MonthPeriod, hour,
                                            DistClearSky, DistClearness,
                                            PValueCvMTestClearSky, PValueCvMTestClearness,
                                            ratioClearSky, ratioClearness)
            )
        end
    end
    return Dict(
        "dfWeatherDistParameters" => dfWeatherDistParameters,
        "dfDataGrouped" => dfDataGrouped
    )
end

t = Juno.@enter IrradiationDistributions(dfIrradiationData)
t = IrradiationDistributions(dfIrradiationData)
c = filter(row -> !isnothing(row.PValueCvMTestClearSky), (t["dfWeatherDistParameters"]))
select!(filter(row -> row.PValueCvMTestClearness < 0.05, c), [:month, :MonthPeriod, :hour, :DistClearness, :PValueCvMTestClearness])

function IrradiationDistributions(dfWeatherData)
    dfData = deepcopy(dfWeatherData)
    dfData.MonthPart =
        Dates.day.(dfData.date_nohour) .> Dates.daysinmonth.(dfData.date_nohour)/2
    dfDataGrouped = groupby(dfData, [:month, :MonthPart])
    GroupsMapping = sort(dfDataGrouped.keymap, by = values)
    dfWeatherDistParameters = DataFrame(month = [], MonthPeriod = [], hour = [],
                                        DistIrradiation = [],
                                        PValueCvMTestIrradiation = [],
                                        ratioIrradiation = [])

    for PeriodNum in 1:24
        CurrentPeriod = GroupsMapping.vals[PeriodNum]
        dfCurrentPeriod = dfDataGrouped[CurrentPeriod]
        month, MonthPeriod = GroupsMapping.keys[PeriodNum]

        for hour in 0:23
            dfCurrentHour = filter(row -> row.hour .== hour, dfCurrentPeriod)
            ratioIrradiation = size(dfCurrentHour[dfCurrentHour.Irradiation.>0, :])[1] / size(dfCurrentHour)[1]
            println("Current month: $month, period: $PeriodNum , hour: $hour")
            println("Irradiation ratio is $ratioIrradiation")
            if ratioIrradiation < 0.5
                DistIrradiation = nothing
                PValueCvMTestIrradiation = nothing
            else
                DistIrradiation = st.beta.fit(dfCurrentHour.Irradiation)
                PValueCvMTestIrradiation = st.cramervonmises(
                    dfCurrentHour.Irradiation, "beta", args = (DistIrradiation)
                ).pvalue
            end
            push!(dfWeatherDistParameters, (month, MonthPeriod, hour,
                                            DistIrradiation,
                                            PValueCvMTestIrradiation,
                                            ratioIrradiation)
            )
        end
    end
    return Dict(
        "dfWeatherDistParameters" => dfWeatherDistParameters,
        "dfDataGrouped" => dfDataGrouped
    )
end

t = IrradiationDistributions(dfIrradiationData)
t["dfWeatherDistParameters"]
c = filter(row -> !isnothing(row.PValueCvMTestIrradiation), t["dfWeatherDistParameters"])
filter(row -> row.PValueCvMTestIrradiation < 0.01, c)

##
# wind production
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



##
# solar production
function SolarCellTemp(TempAmb, Noct, Irradiation; TempConst = 20, IrrConst = 800)
    C = (Noct - TempConst)/IrrConst
    SolarTemp = TempAmb + C * Irradiation
    return SolarTemp
end

function SolarProductionForecast(P_STC, Irradiation, TempAmb, γ_temp, Noct; Irr_STC = 1000, T_STC = 25)
    TempCell = SolarCellTemp(TempAmb = TempAmb, Noct = Noct,
        Irradiation = Irradiation)
    P_output = P_STC * Irradiation / Irr_STC * (1 - γ_temp * (TempCell - T_STC))
    return P_output
end

## plotting
#
function Plotting(dfData, dfDataWithoutMissing)
    plot1 = @df dfDataWithoutMissing StatsPlots.plot(:date, :WindSpeed,
        label = "Wind Speed", legend = :none, lw = 2,
        color = RGB(192/255,0,0), linealpha = 0.6,
        title = "Hourly wind speed")

    plot2 = @df dfDataWithoutMissing StatsPlots.plot(:date, :Irradiation,
            label = "Wind Speed", legend = :none, lw = 2,
            color = RGB(192/255,192/255,192/255), linealpha = 0.6,
            title = "Hourly irradiation")

    plot3 = @df dfDataWithoutMissing StatsPlots.plot(:date, :Temperature,
            label = "Wind Speed", legend = :none, lw = 2,
            color = RGB(100/255,100/255,100/255), linealpha = 0.6,
            title = "Hourly temperature")


    ## plotting monthly averages
    dfWeatherDataGrouped = @pipe groupby(dfData, [:month, :year]) |>
        combine(_, [:WindSpeed => mean => :WindSpeedMonthAvg,
                :Irradiation => mean => :IrradiationMonthAvg,
                :Temperature => mean => :TemperatureMonthAvg,
                :WindSpeed => std => :WindSpeedMonthStd,
                :Irradiation => std => :IrradiationMonthStd,
                :Temperature => std => :TemperatureMonthStd])
    dfWeatherDataGrouped.Date = Dates.Date.(
        Dates.Day(28), Dates.Month.(dfWeatherDataGrouped.month), Dates.Year.(dfWeatherDataGrouped.year)
    )
    dfWeatherDataGrouped[completecases(dfWeatherDataGrouped).==1,:]
    dropmissing!(dfWeatherDataGrouped)
    dfWeatherDataGrouped

    plot4 = @df dfWeatherDataGrouped StatsPlots.plot(:Date, :WindSpeedMonthAvg,
        label = "Wind Speed", legend = :none, lw = 2, xticks = :none,
        color = RGB(192/255,0,0),
        title = "Monthly average of wind speed")
    plot5 = @df dfWeatherDataGrouped StatsPlots.plot(:Date, :TemperatureMonthAvg,
        label = "Temperature", legend = :none, lw = 2,
        color = RGB(100/255,100/255,100/255), xticks = :none,
        title = "Monthly average of temperature")
    plot6 = @df dfWeatherDataGrouped StatsPlots.plot(:Date, :IrradiationMonthAvg,
        label = "Irradiation", legend = :none, lw = 2,
        color = RGB(192/255,192/255,192/255), xticks = :none,
        title = "Monthly average of Irradiation")

    # plot(plot1,plot2,plot3,plot4, layout = (2,2))
    FinalPlot4 = plot(plot4,plot5,plot6, layout = (3,1))

    plot7 = @df dfWeatherDataGrouped StatsPlots.plot(:Date, :WindSpeedMonthStd,
        label = "Wind Speed", legend = :none, lw = 2, xticks = :none,
        color = RGB(192/255,0,0),
        title = "Monthly std of wind speed")
    plot8 = @df dfWeatherDataGrouped StatsPlots.plot(:Date, :TemperatureMonthStd,
        label = "Temperature", legend = :none, lw = 2,
        color = RGB(100/255,100/255,100/255), xticks = :none,
        title = "Monthly std of temperature")
    plot9 = @df dfWeatherDataGrouped StatsPlots.plot(:Date, :IrradiationMonthStd,
        label = "Irradiation", legend = :none, lw = 2,
        color = RGB(192/255,192/255,192/255), xticks = :none,
        title = "Monthly std of Irradiation")

    # plot(plot1,plot2,plot3,plot4, layout = (2,2))
    FinalPlot5 = plot(plot5,plot6,plot7, layout = (3,1))

    MonthsAsStrings = ["Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"]

    plot10 = @df dfWeatherDataGrouped StatsPlots.groupedbar(:month, :IrradiationMonthAvg,
                group = :year,
                bar_position = :dodge,
                color = [RGB(10/255,0,0) RGB(40/255,0,0) RGB(70/255,0,0) RGB(100/255,0,0) RGB(130/255,0,0) RGB(160/255,0,0) RGB(192/255,0,0) RGB(220/255,0,0) RGB(255/255,0,0)],
                title = "Average irradiation",
                xlabel = "Month",
                ylabel = "Average monthly irradiation",
                xticks = (1:12, MonthsAsStrings))

    plot11 = @df dfWeatherDataGrouped StatsPlots.groupedbar(:month, :TemperatureMonthAvg,
                group = :year,
                bar_position = :dodge,
                color = [RGB(10/255,0,0) RGB(40/255,0,0) RGB(70/255,0,0) RGB(100/255,0,0) RGB(130/255,0,0) RGB(160/255,0,0) RGB(192/255,0,0) RGB(220/255,0,0) RGB(255/255,0,0)],
                title = "Average temperature",
                # xticks = ["January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December"]
                xlabel = "Month",
                ylabel = "Average monthly temperature",
                xticks = (1:12, MonthsAsStrings))

    plot12 = @df dfWeatherDataGrouped StatsPlots.groupedbar(:month, :WindSpeedMonthAvg,
                group = :year,
                bar_position = :dodge,
                color = [RGB(10/255,0,0) RGB(40/255,0,0) RGB(70/255,0,0) RGB(100/255,0,0) RGB(130/255,0,0) RGB(160/255,0,0) RGB(192/255,0,0) RGB(220/255,0,0) RGB(255/255,0,0)],
                title = "Average wind speed",
                xlabel = "Month",
                ylabel = "Average monthly wind speed",
                xticks = (1:12, MonthsAsStrings))

    return plot1, plot2, plot3, FinalPlot4, FinalPlot5, plot10, plot11, plot12
end
    # jeden kolor dla barow + srednia wieloletnia dla danego miesiaca -
