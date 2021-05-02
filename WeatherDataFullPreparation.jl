using CSV, DataFrames, SplitApplyCombine
using Plots, Dates, Distributions, Random, StatsPlots
using HypothesisTests, RCall, Pipe, Statistics, Missings
include("SolarAngle.jl")

#using JuliaInterpreter
#push!(JuliaInterpreter.compiled_modules, Base)

## read and clean data
function ReadData(cFileIrr::String, cFileWind::String, cFileTheoretical::String)
    dfWeatherDataIrr = CSV.File(cFileIrr) |>
        DataFrame
    dfWeatherDataIrr = dfWeatherDataIrr[:, ["date", "prom_avg"]]

    dfWeatherDataTempWind = CSV.File(cFileWind) |>
        DataFrame
    dfWeatherDataTempWind = dfWeatherDataTempWind[:,["date", "temp_avg", "predkosc100m_avg"]]

    dfWeatherDataTempTheoretical = CSV.File(cFileTheoretical,
        delim = ";", header = 38) |>
        DataFrame
    dfWeatherDataTempTheoretical = CleanCAMSdata(dfWeatherDataTempTheoretical)

    # joining data sets
    dfWeatherData = DataFrames.innerjoin(dfWeatherDataTempWind, dfWeatherDataIrr, on = :date)
    dfWeatherData["date"] =
        Dates.DateTime.(dfWeatherData.date, DateFormat("y-m-d H:M:S"))
    dfWeatherData = DataFrames.innerjoin(dfWeatherData, dfWeatherDataTempTheoretical, on = :date )
    println(5)
    rename!(dfWeatherData, ["date", "Temperature", "WindSpeed", "Irradiation", "TOA", "GHI"])
#    rename!(dfWeatherData, ["date", "Temperature", "WindSpeed", "Irradiation"])

    ##  missing data are displayed as NAs or Infs
    # # this must be corrected
    for j in 1:ncol(dfWeatherData), i in 1:nrow(dfWeatherData)
        if dfWeatherData[i,j] == "NA"
            dfWeatherData[i,j] = "-999"
        end
    end

#    dfWeatherData[dfWeatherData.WindSpeed .== Inf,:]
    dfWeatherData.WindSpeed[dfWeatherData.WindSpeed .== Inf] .= -999
#    dfWeatherData[dfWeatherData.WindSpeed .== -999,:]

    dfWeatherData.Temperature = parse.(Float64, dfWeatherData.Temperature)
    dfWeatherData.Irradiation = parse.(Float64, dfWeatherData.Irradiation)

    dfWeatherData["date_nohour"] = Dates.Date.(dfWeatherData["date"])
    dfWeatherData["month"] = Dates.month.(dfWeatherData["date"])
    dfWeatherData["hour"] = Dates.hour.(dfWeatherData["date"])
    dfWeatherData["year"] = Dates.year.(dfWeatherData["date"])

    allowmissing!(dfWeatherData, [:Temperature, :Irradiation, :WindSpeed])
    for j in 1:ncol(dfWeatherData), i in 1:nrow(dfWeatherData)
        if dfWeatherData[i,j] == -999
            dfWeatherData[i,j] = missing
        end
    end

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

    select!(dfWeatherData,
        [:date, :date_nohour, :year, :month, :hour,
         :Temperature, :WindSpeed, :Irradiation, :ClearnessIndex, :ClearSkyIndex,
         :TOA, :GHI, :SunPosition])

#    dfWeatherDataNoMissing = dropmissing(dfWeatherData)

    # dfWeatherDataNoMissing.Irradiation[dfWeatherDataNoMissing.Irradiation .< 2] = 0

#    dfWeatherDataNoMissing.ClearnessIndex = ClearnessIndex.(
#        dfWeatherDataNoMissing.Irradiation, Dates.dayofyear.(dfWeatherDataNoMissing.date_nohour),
#        dfWeatherDataNoMissing.hour, Dates.isleapyear.(dfWeatherDataNoMissing.date_nohour)
#    )
#    dfWeatherDataNoMissing.ClearnessIndex = dfWeatherDataNoMissing.Irradiation./1366.1

#    return dfWeatherDataNoMissing
    return dfWeatherData
end

function CleanCAMSdata(dfData::DataFrame)
    rename!(dfData, ["Date", "TOA", "GHI", "BHI", "DHI", "BNI"])
    insertcols!(dfData, ([:date, :DateLocal] .=>
        invert(split.(dfData.Date, "/")))...,
                       makeunique=true)
    select!(dfData, [:date, :TOA, :GHI])
    dfData.date = Dates.DateTime.(dfData.date)
    return dfData
end

dfWeatherDataAll = ReadData("C:/Users/Marcel/Desktop/mgr/data/weather_data_irr.csv",
             "C:/Users/Marcel/Desktop/mgr/data/weather_data_temp_wind.csv",
             "C:/Users/Marcel/Desktop/mgr/data/clear_sky_irradiation_CAMS.csv")

MissingIrradiation = filter(row -> ismissing(row.Irradiation), dfWeatherDataAll)
MissingWind = filter(row -> ismissing(row.WindSpeed), dfWeatherDataAll)
MissingTemp = filter(row -> ismissing(row.Temperature), dfWeatherDataAll)

a = antijoin(MissingIrradiation, MissingWind, on = :date)
b = antijoin(MissingIrradiation, MissingTemp, on = :date)
c = antijoin(MissingWind, MissingTemp, on = :date)
d = antijoin(MissingTemp, MissingWind, on = :date)
e = antijoin(MissingWind, MissingIrradiation, on = :date)
f = antijoin(MissingTemp, MissingIrradiation, on = :date)

zz = filter(row -> ismissing(row.Irradiation), dfWeatherDataAll)
zzz = @pipe groupby(zz, [:year, :month]) |>
    combine(_, nrow => :MissingCount)
unique(filter(row -> (row.year==2016 && row.month==7), zz).date_nohour)
filter(row -> (row.year==2011 && row.month == 5), zz)
filter(row -> (row.year==2011 && row.month == 8), zz)
filter(row -> (row.year==2011 && row.month == 11), zz)
filter(row -> (row.year==2012 && row.month == 3), zz)
filter(row -> (row.year==2016 && row.month == 7), zz)
filter(row -> (row.year==2016 && row.month == 8), zz)
filter(row -> (row.year==2016 && row.month == 12), zz)
filter(row -> (row.year==2018 && row.month == 2), zz)
filter(row -> (row.year==2018 && row.month == 4), zz)
filter(row -> (row.year==2018 && row.month == 5), zz)
filter(row -> (row.year==2018 && row.month == 6), zz)




yy = filter(row -> ismissing(row.WindSpeed), dfWeatherDataAll)
yyy = @pipe groupby(yy, [:year, :month]) |>
    combine(_, nrow => :MissingCount)

xx = filter(row -> ismissing(row.Temperature), dfWeatherDataAll)
xxx = @pipe groupby(xx, [:year, :month]) |>
    combine(_, nrow => :MissingCount)

heatmap(unique(xxx.year), unique(xxx.month), xxx.MissingCount)
heatmap(xxx.MissingCount)


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
# Solar prod functions

# Theta
function GetTheta(DayOfYear, IsLeapYear)
    if IsLeapYear && DayOfYear > Dates.dayofyear(Date("2020-02-28"))
        Θ = 2*π*(DayOfYear - 2)/365
    else
        Θ = 2*π*(DayOfYear - 1)/365
    end
    return Θ
end

function GetEccentricityCorrection(Θ)
    E0 = 1.00011 + 0.034221*cos(Θ) + 0.00128*sin(Θ) -
        0.000719*cos(2*Θ) + 0.000077*sin(2*Θ)
    return E0
end

function GetZenithAngle(Θ, DayOfYear, HourOfDay;
                        Latitude = (50 + 17/60), Longitude = (19 + 8/60),
                        LongitudeStandard = 15)
    δ = 0.006918 - 0.399912 * cos(Θ) + 0.070257 * sin(Θ) -                                      # solar declination
        0.006759 * cos(2*Θ) +  0.000907 * sin(2*Θ) + 0.00148 * sin(3*Θ) -
        0.002697 * cos(3*Θ)

    Et = 0.000075 + 0.001868 * cos(Θ) - 0.032077 * sin(Θ) -
        0.14615*cos(2*Θ) - 0.04084*sin(2*Θ)                                                     # equation of time

    SolarHour = HourOfDay + (LongitudeStandard-Longitude) / 15 + Et                                           # solar hour

    ω = 2*π/24*(SolarHour - 12)                                                                 # hour angle

    CosZenithAngle = sin(Latitude) * sin(δ) + cos(Latitude) * cos(δ) * cos(ω)
    return δ, Et, SolarHour, ω, CosZenithAngle
end

# index clearness
function ClearnessIndex(IncidentalIrradiance, DayOfYear, HourOfDay, IsLeapYear;
                        Latitude = (50 + 17/60), Longitude = (19 + 8/60),
                        LongitudeStandard = 15)   # Paulescu et al, ch 5 + Badescu et al ch. 3.4
    Θ = GetTheta(DayOfYear, IsLeapYear)                                                               # Θ, argument Et i E0

    E0 = GetEccentricityCorrection(Θ)

    CosZenithAngle = GetZenithAngle(Θ, DayOfYear, HourOfDay)[5]

    k = max(IncidentalIrradiance / (1366 * E0 * CosZenithAngle), 0)
    k = min(k,1)
    return k
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
