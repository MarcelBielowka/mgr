using CSV, DataFrames, SplitApplyCombine
using Plots, Dates, Distributions, Random, StatsPlots
using HypothesisTests, RCall, PyCall
using Pipe, Statistics, Missings
using Impute
include("SolarAngle.jl")

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
Redemption["MissingWindData"]
GroupedMissingDataWind = @pipe groupby(Redemption["MissingWindData"], [:year, :month]) |>
    combine(_, nrow => :MissingCount)
GroupedMissingDataTemp = @pipe groupby(Redemption["MissingTempData"], [:year, :month]) |>
    combine(_, nrow => :MissingCount)
c["WindTempDataNoMissing"]

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

    dfWeatherData[:SunPosition] = SunPosition.(dfWeatherData.year,
                                               dfWeatherData.month,
                                               Dates.day.(dfWeatherData.date),
                                               dfWeatherData.hour
    )
    dfWeatherData.Irradiation[dfWeatherData.SunPosition .< 10] .= 0
    dfWeatherData[:ClearSkyIndex] = zeros(size(dfWeatherData)[1])
    dfWeatherData[:ClearnessIndex] = zeros(size(dfWeatherData)[1])

    dfWeatherData.ClearSkyIndex[(dfWeatherData.Irradiation .> 0) .& (ismissing.(dfWeatherData.Irradiation).==0)] =
        dfWeatherData.Irradiation[(dfWeatherData.Irradiation .> 0) .& (ismissing.(dfWeatherData.Irradiation).==0)] ./
        dfWeatherData.GHI[(dfWeatherData.Irradiation .> 0) .& (ismissing.(dfWeatherData.Irradiation).==0)]

    dfWeatherData.ClearnessIndex[(dfWeatherData.Irradiation .> 0) .& (ismissing.(dfWeatherData.Irradiation).==0)] =
        dfWeatherData.Irradiation[(dfWeatherData.Irradiation .> 0) .& (ismissing.(dfWeatherData.Irradiation).==0)] ./
        dfWeatherData.TOA[(dfWeatherData.Irradiation .> 0) .& (ismissing.(dfWeatherData.Irradiation).==0)]


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
        "OutputIrradiationData" => dfOutputData
    )

end

dfIrradiationData = ReadIrradiationData("C:/Users/Marcel/Desktop/mgr/data/weather_data_irr.csv",
                        "C:/Users/Marcel/Desktop/mgr/data/clear_sky_irradiation_CAMS.csv")
dfIrradiationData = RemedyMissingIrradiationData(dfIrradiationData)["OutputIrradiationData"]

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

dfIrradiationData = CalculateIndex(dfIrradiationData)

zz = filter(row -> ismissing(row.Irradiation), dfIrradiationData)
zzz = @pipe groupby(zz, [:year, :month]) |>
        combine(_, nrow => :MissingCount)


## Grouping data for modelling purposes

function RetrieveGroupedData(dfWeatherData; kelvins::Bool = true)
    if kelvins
        dfWeatherData.Temperature = dfWeatherData.Temperature .+ 273.15
    end

    dfWeatherData.MonthPart =
        Dates.day.(dfWeatherData.date_nohour) .> Dates.daysinmonth.(dfWeatherData.date_nohour)/2

    dfWeatherDataGrouped = groupby(dfWeatherData, [:month, :MonthPart])

    GroupsMapping = sort(dfWeatherDataGrouped.keymap, by = values)

    WeatherDistParameters = Dict{}()

    for PeriodNum in 1:24
        CurrentPeriod = GroupsMapping.vals[PeriodNum]
        dfCurrentPeriod = dfWeatherDataGrouped[CurrentPeriod]
        month, MonthPeriod = GroupsMapping.keys[PeriodNum]

        for hour in extrema(dfWeatherDataGrouped[1].hour)[1]:extrema(dfWeatherDataGrouped[1].hour)[2]
            dfCurrentHour = filter(row -> row.hour .== hour, dfCurrentPeriod)
            println("Current month: $month, period: $PeriodNum , hour: $hour")

            DistWindMASS = fitdistr(dfCurrentHour.WindSpeed[dfCurrentHour.WindSpeed.>0], "weibull", lower = R"c(0,0)")
            if length(dfCurrentHour.ClearnessIndex[dfCurrentHour.ClearnessIndex.>0.01]) > 30
                try
                    DistSolarMASS = fitdistr(dfCurrentHour.ClearnessIndex, "beta", start = start = R"list(shape1 = 1, shape2 = 1)")
                catch
                    DistSolarMASS = fitdistr(dfCurrentHour.ClearnessIndex[dfCurrentHour.ClearnessIndex .> 0.0001], "beta", start = start = R"list(shape1 = 1, shape2 = 1)")
                end
            else
                DistSolarMASS = nothing
            end
            DistTempMASS = fitdistr(dfCurrentHour.Temperature, "normal")

            push!(WeatherDistParameters, (month, MonthPeriod, hour) => ["WindParam" => [DistWindMASS[1][1] DistWindMASS[1][2]],
                                                                          "SolarParam" => !isnothing(DistSolarMASS) ? [DistSolarMASS[1][1] DistSolarMASS[1][2]] : nothing,
                                                                          "TempParam" => [DistTempMASS[1][1] DistTempMASS[1][2]],
                                                                   ])
        end
    end

    return WeatherDistParameters, dfWeatherDataGrouped
end

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
