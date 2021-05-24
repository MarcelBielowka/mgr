using CSV, DataFrames, SplitApplyCombine
using Plots, Dates, Distributions, Random, StatsPlots
using Pipe, Statistics, Missings
include("SolarAngle.jl")

#using JuliaInterpreter
#push!(JuliaInterpreter.compiled_modules, Base)

## read and clean data

function ReadWindAndTempData(cFileWind::String; FilterStart = nothing, FilterEnd = nothing)
    dfWindData = CSV.File(cFileWind) |>
        DataFrame
    select!(dfWindData, [:date, :temp_avg, :predkosc100m_avg])
    rename!(dfWindData, [:date, :Temperature, :WindSpeed])

    dfWindData[!, "date"] =
        Dates.DateTime.(dfWindData.date, DateFormat("y-m-d H:M:S"))
    dfWindData.Temperature[dfWindData.Temperature .== "NA"] .= "Inf"
    dfWindData.Temperature = parse.(Float64, dfWindData.Temperature)

    allowmissing!(dfWindData)
    dfWindData.Temperature[dfWindData.Temperature .== Inf] .= missing
    dfWindData.WindSpeed[dfWindData.WindSpeed .== Inf] .= missing

    dfWindData[!, "date_nohour"] = Dates.Date.(dfWindData.date)
    dfWindData[!, "month"] = Dates.month.(dfWindData.date)
    dfWindData[!, "hour"] = Dates.hour.(dfWindData.date)
    dfWindData[!, "year"] = Dates.year.(dfWindData.date)

    if !isnothing(FilterStart)
        filter!(row -> row.date >= Dates.Date(FilterStart), dfWindData)
    end

    if !isnothing(FilterEnd)
        StringEndDate = FilterEnd * "T23:59:00"
        filter!(row -> row.date <= Dates.DateTime(StringEndDate), dfWindData)
    end

    return dfWindData
end

function RemedyMissingWindTempData(dfWindData)
    MissingWindData = filter(row -> ismissing(row.WindSpeed), dfWindData)
    GroupedMissingDataWind = @pipe groupby(MissingWindData, [:year, :month]) |>
        combine(_, nrow => :MissingCount)
    MissingTempData = filter(row -> ismissing(row.Temperature), dfWindData)
    GroupedMissingDataTemp = @pipe groupby(MissingTempData, [:year, :month]) |>
        combine(_, nrow => :MissingCount)
    dfWindDataClean = dropmissing(dfWindData)
    return Dict(
        "MissingDataWind" => MissingWindData,
        "MissingDataTemp" => MissingTempData,
        "GroupedMissingDataWind" => GroupedMissingDataWind,
        "GroupedMissingDataTemp" => GroupedMissingDataTemp,
        "WindTempDataNoMissing" => dfWindDataClean
    )
end

#dfWindTempData = ReadWindAndTempData("C:/Users/Marcel/Desktop/mgr/data/weather_data_temp_wind.csv")
#dfWindTempData = ReadWindAndTempData("C:/Users/Marcel/Desktop/mgr/data/weather_data_temp_wind.csv",
#    FilterStart = "2019-01-01")
#dfWindTempData = ReadWindAndTempData("C:/Users/Marcel/Desktop/mgr/data/weather_data_temp_wind.csv",
#    FilterEnd = "2017-12-31")
#Redemption = RemedyMissingWindTempData(dfWindTempData)
#dfMissingDataWind = Redemption["GroupedMissingDataWind"]
#dfMissingDataTemp = Redemption["GroupedMissingDataTemp"]
#dfWindTempDataFinal = Redemption["WindTempDataNoMissing"]

function ReadIrradiationData(cFileIrr::String; FilterStart = nothing, FilterEnd = nothing)
    dfWeatherData = CSV.File(cFileIrr) |>
        DataFrame
    select!(dfWeatherData, [:date, :prom_avg])
    dfWeatherData.date = Dates.DateTime.(dfWeatherData.date, DateFormat("y-m-d H:M:S"))

    rename!(dfWeatherData, ["date", "Irradiation"])

    dfWeatherData.Irradiation[dfWeatherData.Irradiation .== "NA"] .= "Inf"
    dfWeatherData.Irradiation = parse.(Float64, dfWeatherData.Irradiation)
    allowmissing!(dfWeatherData)
    dfWeatherData.Irradiation[dfWeatherData.Irradiation .== Inf] .= missing

    dfWeatherData[!, "date_nohour"] = Dates.Date.(dfWeatherData[!, "date"])
    dfWeatherData[!, "month"] = Dates.month.(dfWeatherData[!, "date"])
    dfWeatherData[!, "hour"] = Dates.hour.(dfWeatherData[!, "date"])
    dfWeatherData[!, "year"] = Dates.year.(dfWeatherData[!, "date"])

    if !isnothing(FilterStart)
        filter!(row -> row.date >= Dates.Date(FilterStart), dfWeatherData)
    end

    if !isnothing(FilterEnd)
        StringEndDate = FilterEnd * "T23:59:00"
        filter!(row -> row.date <= Dates.DateTime(StringEndDate), dfWeatherData)
    end

    return dfWeatherData
end

function CorrectIrradiationDataForSolarAngle(dfIrrData)
    dfIrradiationData = deepcopy(dfIrrData)
    insertcols!(dfIrradiationData, :SolarAngle => SunPosition.(
            dfIrradiationData.year, dfIrradiationData.month,
            Dates.day.(dfIrradiationData.date), dfIrradiationData.hour
        )
    )
    dfIrradiationData.Irradiation[dfIrradiationData.SolarAngle .< 10] .= 0
    return dfIrradiationData
end

function RemedyMissingIrradiationData(dfIrrData)
    dfMissingIrradiationData = filter(row -> ismissing(row.Irradiation), dfIrrData)
    GroupedMissingIrradiationData = @pipe groupby(dfMissingIrradiationData, [:year, :month]) |>
            combine(_, nrow => :MissingCount)
    dfOutputData = dropmissing(dfIrrData)
    dfOutputData = CorrectIrradiationDataForSolarAngle(dfOutputData)
    return Dict(
        "MissingDataIrradiation" => dfMissingIrradiationData,
        "GruopedMissingDataIrradiation" => GroupedMissingIrradiationData,
        "IrradiationDataNoMissing" => dfOutputData
    )
end

#dfIrradiationData = ReadIrradiationData("C:/Users/Marcel/Desktop/mgr/data/weather_data_irr.csv")
#dfIrradiationData = ReadIrradiationData("C:/Users/Marcel/Desktop/mgr/data/weather_data_irr.csv",
#    FilterStart = "2019-01-01")
#dfIrradiationData = ReadIrradiationData("C:/Users/Marcel/Desktop/mgr/data/weather_data_irr.csv",
#    FilterEnd = "2018-12-31")
#dfIrradiationData = ReadIrradiationData("C:/Users/Marcel/Desktop/mgr/data/weather_data_irr.csv",
#    FilterStart = "2012-01-01", FilterEnd = "2017-12-31")
#dfIrradiationData = RemedyMissingIrradiationData(dfIrradiationData)["IrradiationDataNoMissing"]
#dfIrradiationData = CalculateIndex(dfIrradiationData)

function ReadWeatherData(cFileWind::String, cFileIrr::String; FilterStart = nothing, FilterEnd = nothing)
    dfRawWindTempData = ReadWindAndTempData(cFileWind, FilterStart = FilterStart, FilterEnd = FilterEnd)
    ProcessedWindTempData = RemedyMissingWindTempData(dfRawWindTempData)
    dfRawIrrData = ReadIrradiationData(cFileIrr, FilterStart = FilterStart, FilterEnd = FilterEnd)
    ProcessedIrrData = RemedyMissingIrradiationData(dfRawIrrData)
    dfFinalWeatherData = DataFrames.innerjoin(
        ProcessedWindTempData["WindTempDataNoMissing"], ProcessedIrrData["IrradiationDataNoMissing"],
        on = :date, makeunique = true
    )
    select!(dfFinalWeatherData, [:date, :Temperature, :WindSpeed, :Irradiation])

    return Dict(
        "dfFinalWeatherData" => dfFinalWeatherData,
        "DetailsWindTempData" => ProcessedWindTempData,
        "DetailsIrradiationData" => ProcessedIrrData
    )
end

test = ReadWeatherData("C:/Users/Marcel/Desktop/mgr/data/weather_data_temp_wind.csv",
                       "C:/Users/Marcel/Desktop/mgr/data/weather_data_irr.csv",
                       FilterStart = "2019-01-01")

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
