using CSV, DataFrames, Plots, Dates, Distributions, Random, StatsPlots
using HypothesisTests, RCall, Pipe, Statistics, Missings

## read and clean data
dfWeatherDataIrr = CSV.File("C:/Users/Marcel/Desktop/mgr/data/weather_data_irr.csv") |>
    DataFrame
dfWeatherDataIrr = dfWeatherDataIrr[:, ["date", "prom_avg"]]

dfWeatherDataTempWind = CSV.File("C:/Users/Marcel/Desktop/mgr/data/weather_data_temp_wind.csv") |>
    DataFrame
dfWeatherDataTempWind = dfWeatherDataTempWind[:,["date", "temp_avg", "predkosc100m_avg"]]

# joining both data sets
dfWeatherData = DataFrames.innerjoin(dfWeatherDataTempWind, dfWeatherDataIrr, on = :date)
rename!(dfWeatherData, ["date", "Temperature", "WindSpeed", "Irradiation"])
dfWeatherData["date"] =
    Dates.DateTime.(dfWeatherData.date, DateFormat("y-m-d H:M:S"))

##  missing data are displayed as NAs or Infs
# # this must be corrected
for j in 1:ncol(dfWeatherData), i in 1:nrow(dfWeatherData)
    if dfWeatherData[i,j] == "NA"
        dfWeatherData[i,j] = "-999"
    end
end

dfWeatherData[dfWeatherData.WindSpeed .== Inf,:]
dfWeatherData.WindSpeed[dfWeatherData.WindSpeed .== Inf] .= -999
dfWeatherData[dfWeatherData.WindSpeed .== -999,:]

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

dfWeatherDataNoMissing = dropmissing(dfWeatherData)

plot1 = @df dfWeatherDataNoMissing StatsPlots.plot(:date, :WindSpeed,
    label = "Wind Speed", legend = :none, lw = 2,
    color = RGB(192/255,0,0), linealpha = 0.6,
    title = "Hourly wind speed")

plot2 = @df dfWeatherDataNoMissing StatsPlots.plot(:date, :Irradiation,
        label = "Wind Speed", legend = :none, lw = 2,
        color = RGB(192/255,192/255,192/255), linealpha = 0.6,
        title = "Hourly irradiation")

plot3 = @df dfWeatherDataNoMissing StatsPlots.plot(:date, :Temperature,
        label = "Wind Speed", legend = :none, lw = 2,
        color = RGB(100/255,100/255,100/255), linealpha = 0.6,
        title = "Hourly temperature")


## plotting monthly averages
dfWeatherDataGrouped = @pipe groupby(dfWeatherData, [:month, :year]) |>
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

plot1 = @df dfWeatherDataGrouped StatsPlots.plot(:Date, :WindSpeedMonthAvg,
    label = "Wind Speed", legend = :none, lw = 2, xticks = :none,
    color = RGB(192/255,0,0),
    title = "Monthly average of wind speed")
plot2 = @df dfWeatherDataGrouped StatsPlots.plot(:Date, :TemperatureMonthAvg,
    label = "Temperature", legend = :none, lw = 2,
    color = RGB(100/255,100/255,100/255), xticks = :none,
    title = "Monthly average of temperature")
plot3 = @df dfWeatherDataGrouped StatsPlots.plot(:Date, :IrradiationMonthAvg,
    label = "Irradiation", legend = :none, lw = 2,
    color = RGB(192/255,192/255,192/255), xticks = :none,
    title = "Monthly average of Irradiation")
plot4 = plot()

plot(plot1,plot2,plot3,plot4, layout = (2,2))

plot1 = @df dfWeatherDataGrouped StatsPlots.plot(:Date, :WindSpeedMonthStd,
    label = "Wind Speed", legend = :none, lw = 2, xticks = :none,
    color = RGB(192/255,0,0),
    title = "Monthly std of wind speed")
plot2 = @df dfWeatherDataGrouped StatsPlots.plot(:Date, :TemperatureMonthStd,
    label = "Temperature", legend = :none, lw = 2,
    color = RGB(100/255,100/255,100/255), xticks = :none,
    title = "Monthly std of temperature")
plot3 = @df dfWeatherDataGrouped StatsPlots.plot(:Date, :IrradiationMonthStd,
    label = "Irradiation", legend = :none, lw = 2,
    color = RGB(192/255,192/255,192/255), xticks = :none,
    title = "Monthly std of Irradiation")
plot4 = plot()

plot(plot1,plot2,plot3,plot4, layout = (2,2))

plot1 = @df dfWeatherDataGrouped StatsPlots.groupedbar(:month, :IrradiationMonthAvg,
            group = :year,
            bar_position = :dodge,
            color = [RGB(10/255,0,0) RGB(40/255,0,0) RGB(70/255,0,0) RGB(100/255,0,0) RGB(130/255,0,0) RGB(160/255,0,0) RGB(192/255,0,0) RGB(220/255,0,0) RGB(255/255,0,0)],
            title = "Average irradiation",
            xlabel = "Month",
            ylabel = "Average monthly irradiation")

plot2 = @df dfWeatherDataGrouped StatsPlots.groupedbar(:month, :TemperatureMonthAvg,
            group = :year,
            bar_position = :dodge,
            color = [RGB(10/255,0,0) RGB(40/255,0,0) RGB(70/255,0,0) RGB(100/255,0,0) RGB(130/255,0,0) RGB(160/255,0,0) RGB(192/255,0,0) RGB(220/255,0,0) RGB(255/255,0,0)],
            title = "Average temperature",
            # xticks = ["January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December"]
            xlabel = "Month",
            ylabel = "Average monthly temperature")

plot3 = @df dfWeatherDataGrouped StatsPlots.groupedbar(:month, :WindSpeedMonthAvg,
            group = :year,
            bar_position = :dodge,
            color = [RGB(10/255,0,0) RGB(40/255,0,0) RGB(70/255,0,0) RGB(100/255,0,0) RGB(130/255,0,0) RGB(160/255,0,0) RGB(192/255,0,0) RGB(220/255,0,0) RGB(255/255,0,0)],
            title = "Average wind speed",
            xlabel = "Month",
            ylabel = "Average monthly wind speed")

groupedbar(data, color = [:red, :green, :blue])
groupedbar(data, color = [:red :green :blue])
