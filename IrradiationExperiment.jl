using CSV, DataFrames, SplitApplyCombine, Dates
using Pipe: @pipe

dfWeatherDataIrr = CSV.File("C:/Users/Marcel/Desktop/mgr/data/weather_data_irr.csv") |>
    DataFrame
dfWeatherDataIrr = dfWeatherDataIrr[:, ["date", "prom_avg"]]

for j in 1:ncol(dfWeatherDataIrr), i in 1:nrow(dfWeatherDataIrr)
    if dfWeatherDataIrr[i,j] == "NA"
        dfWeatherDataIrr[i,j] = "-999"
        # parse.(Int, dfWeatherDataIrr[i,j])
        # dfWeatherDataIrr[i,j] = nothing
    end
end

dfWeatherDataIrr.prom_avg = parse.(Float64, dfWeatherDataIrr.prom_avg)

dfWeatherDataIrr[:prom_avg] = recode(dfWeatherDataIrr[:prom_avg], -999 => missing)
dropmissing!(dfWeatherDataIrr)

dfWeatherDataIrr["date"] =
    Dates.DateTime.(dfWeatherDataIrr.date, DateFormat("y-m-d H:M:S"))
filter!(row -> row.date > DateTime("2018-12-31T23:40"), dfWeatherDataIrr)

dfClearSkyIrr = CSV.File(
    "C:/Users/Marcel/Desktop/mgr/data/clear_sky_irradiation_CAMS.csv",
    delim = ";", header = 38) |> DataFrame

rename!(dfClearSkyIrr, ["Date", "TOA", "GHI", "BHI", "DHI", "BNI"])

insertcols!(dfClearSkyIrr, ([:date, :DateLocal] .=>
    invert(split.(dfClearSkyIrr.Date, "/")))...,
                   makeunique=true)
dfClearSkyIrr2 = select(dfClearSkyIrr, ["date", "TOA", "GHI", "BHI", "DHI", "BNI"])

#insertcols!(dfClearSkyIrr2, ([:Date, :Hour] .=>
#    invert(split.(dfClearSkyIrr.DateLocal, "T")))...,
#                   makeunique=true)
#dfClearSkyIrr2.Date = Dates.Date.(dfClearSkyIrr2, DateFormat("y-m-d"))
dfClearSkyIrr2.date = Dates.DateTime.(dfClearSkyIrr2.date, DateFormat("y-m-dTH:M:S.MS"))
#dfClearSkyIrr2.DateNoHour = Dates.Date.(dfClearSkyIrr2.date)
#dfClearSkyIrr2.Hour = Dates.hour.(dfClearSkyIrr2.DateLocal)

#dfClearSkyIrr["DateLocal"] = Dates.Date.(dfClearSkyIrr.DateLocal, DateFormat("y-m-dTH:M:S.MS"))
#dfClearSkyIrr.DateLocal[1]
filter!(row -> row.date .> Dates.Date("2018-12-31"), dfClearSkyIrr2)

dfIrrDataFull = leftjoin(dfWeatherDataIrr, dfClearSkyIrr2, on = [:date])
dropmissing!(dfIrrDataFull)

dfIrrDataFull.ClearSkyIndex .= 0

dfIrrDataFull.ClearSkyIndex[dfIrrDataFull.GHI.>0.1] =
    dfIrrDataFull.prom_avg[dfIrrDataFull.GHI.>0.1] ./ dfIrrDataFull.GHI[dfIrrDataFull.GHI.>0.1]
z = filter(row-> row.ClearSkyIndex > 1, dfIrrDataFull)
t = deepcopy(dfIrrDataFull)
t.ClearSkyIndex[t.GHI.<2] .= 0
t.ClearSkyIndex = t.prom_avg ./ t.GHI
zt = filter(row-> row.ClearSkyIndex > 1, t)
