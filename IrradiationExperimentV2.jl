using CSV, DataFrames, SplitApplyCombine, Dates
using Pipe: @pipe
using PyCall
using StatsPlots
using HypothesisTests
st = pyimport("scipy.stats")

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
    "C:/Users/Marcel/Desktop/mgr/data/theoretical_irradiation_NOAA.csv",
    delim = ";") |> DataFrame

rename!(dfClearSkyIrr, ["date", "solar_azimuth", "solar_elevation", "I0", "I_direct_normal", "I_direct_horizontal", "I_global_horizontal", "I_diffuse", "data"])
select!(dfClearSkyIrr, ["date", "solar_elevation", "I_global_horizontal"])
dfClearSkyIrr.date = Dates.DateTime.(dfClearSkyIrr.date, DateFormat("y-m-d H:M"))

dfIrrDataFull = leftjoin(dfWeatherDataIrr, dfClearSkyIrr, on = [:date])
dropmissing!(dfIrrDataFull)

dfIrrDataFull.ClearSkyIndex = zeros(size(dfIrrDataFull)[1])

dfIrrDataFull.ClearSkyIndex[dfIrrDataFull.solar_elevation.>10] =
    dfIrrDataFull.prom_avg[dfIrrDataFull.solar_elevation.>10] ./ dfIrrDataFull.I_global_horizontal[dfIrrDataFull.solar_elevation.>10]
dfIrrDataFull.Quarter = Dates.quarter.(dfIrrDataFull.date)
dfIrrDataFull.Month = Dates.month.(dfIrrDataFull.date)
dfIrrDataFull.hour = Dates.hour.(dfIrrDataFull.date)
z = filter(row-> row.ClearSkyIndex > 1, dfIrrDataFull)
y = filter(row-> row.ClearSkyIndex > 0, dfIrrDataFull)

TestData1 = filter(row -> (Dates.month(row.date) < 4 && Dates.hour(row.date) == 12), dfIrrDataFull)
DistClearSky = st.beta.fit(TestData1.ClearSkyIndex)
PValueCvMTestClearSky = st.cramervonmises(
    TestData1.ClearSkyIndex, "beta", args = (DistClearSky)
).pvalue

tra = plot(dfIrrDataFull.date, dfIrrDataFull.ClearSkyIndex,
    title = "Clear Sky index across the year")
bra = plot(dfIrrDataFull.date, dfIrrDataFull.I_global_horizontal,
    title = "Irradiation across the year")
bra = plot(dfIrrDataFull.date[dfIrrDataFull.Month.==5], dfIrrDataFull.ClearSkyIndex[dfIrrDataFull.Month.==5],
    title = "Irradiation across the month of May")

zra = plot(dfIrrDataFull.date[(dfIrrDataFull.Month.==2) .& (dfIrrDataFull.ClearSkyIndex .> 0)],
    dfIrrDataFull.ClearSkyIndex[(dfIrrDataFull.Month.==2) .& (dfIrrDataFull.ClearSkyIndex .> 0)],
    title = "Clear Sky index across the month of February")

zra = plot(dfIrrDataFull.date[(dfIrrDataFull.Month.==5) .& (dfIrrDataFull.ClearSkyIndex .> 0)],
    dfIrrDataFull.ClearSkyIndex[(dfIrrDataFull.Month.==5) .& (dfIrrDataFull.ClearSkyIndex .> 0)],
    title = "Clear Sky index across the month of May")

zra = plot(dfIrrDataFull.date[(dfIrrDataFull.Month.==8) .& (dfIrrDataFull.ClearSkyIndex .> 0)],
    dfIrrDataFull.ClearSkyIndex[(dfIrrDataFull.Month.==8) .& (dfIrrDataFull.ClearSkyIndex .> 0)],
    title = "Clear Sky index across the month of August")

zra = plot(dfIrrDataFull.date[(dfIrrDataFull.Month.==11) .& (dfIrrDataFull.ClearSkyIndex .> 0)],
    dfIrrDataFull.ClearSkyIndex[(dfIrrDataFull.Month.==11) .& (dfIrrDataFull.ClearSkyIndex .> 0)],
    title = "Clear Sky index across the month of November")

zra = plot(dfIrrDataFull.hour[Dates.Date.(dfIrrDataFull.date) .== Dates.Date("2019-08-18")],
    dfIrrDataFull.ClearSkyIndex[Dates.Date.(dfIrrDataFull.date) .== Dates.Date("2019-08-18")],
    title = "Clear Sky index across 18.08")

zra = plot(dfIrrDataFull.date[(dfIrrDataFull.date .>= Dates.DateTime("2019-08-01")) .& (dfIrrDataFull.date .<= Dates.DateTime("2019-08-07")) .& (dfIrrDataFull.ClearSkyIndex .> 0)],
    dfIrrDataFull.ClearSkyIndex[(dfIrrDataFull.date .>= Dates.DateTime("2019-08-01")) .& (dfIrrDataFull.date .<= Dates.DateTime("2019-08-07")) .& (dfIrrDataFull.ClearSkyIndex .> 0)],
    title = "Clear Sky index across the first week of August")

zra = bar(dfIrrDataFull.date[(dfIrrDataFull.date .>= Dates.DateTime("2019-08-01")) .& (dfIrrDataFull.date .<= Dates.DateTime("2019-08-07"))],
    dfIrrDataFull.ClearSkyIndex[(dfIrrDataFull.date .>= Dates.DateTime("2019-08-01")) .& (dfIrrDataFull.date .<= Dates.DateTime("2019-08-07"))],
    title = "Clear Sky index across the first week of August")

zra1 = bar(dfIrrDataFull.date[(dfIrrDataFull.date .>= Dates.DateTime("2019-11-01")) .& (dfIrrDataFull.date .<= Dates.DateTime("2019-11-07"))],
    dfIrrDataFull.ClearSkyIndex[(dfIrrDataFull.date .>= Dates.DateTime("2019-11-01")) .& (dfIrrDataFull.date .<= Dates.DateTime("2019-11-07"))])

zra2 = bar(dfIrrDataFull.date[(dfIrrDataFull.date .>= Dates.DateTime("2019-11-08")) .& (dfIrrDataFull.date .<= Dates.DateTime("2019-11-14"))],
    dfIrrDataFull.ClearSkyIndex[(dfIrrDataFull.date .>= Dates.DateTime("2019-11-08")) .& (dfIrrDataFull.date .<= Dates.DateTime("2019-11-14"))])

zra3 = bar(dfIrrDataFull.date[(dfIrrDataFull.date .>= Dates.DateTime("2019-11-15")) .& (dfIrrDataFull.date .<= Dates.DateTime("2019-11-21"))],
    dfIrrDataFull.ClearSkyIndex[(dfIrrDataFull.date .>= Dates.DateTime("2019-11-15")) .& (dfIrrDataFull.date .<= Dates.DateTime("2019-11-21"))])

zra4 = bar(dfIrrDataFull.date[(dfIrrDataFull.date .>= Dates.DateTime("2019-11-22")) .& (dfIrrDataFull.date .<= Dates.DateTime("2019-11-29"))],
    dfIrrDataFull.ClearSkyIndex[(dfIrrDataFull.date .>= Dates.DateTime("2019-11-22")) .& (dfIrrDataFull.date .<= Dates.DateTime("2019-11-29"))])

plot(zra1, zra2, zra3, zra4, layout = (2,2), size = (1200, 800))


HypothesisTests.ADFTest(dfIrrDataFull.ClearSkyIndex, :none, 24)
HypothesisTests.ADFTest(dfIrrDataFull.I_global_horizontal, :constant, 24)




function IrradiationDistributions(dfWeatherData; disttype = "weibull_min")
    dfData = deepcopy(dfWeatherData)
    dfDataGrouped = groupby(dfData, :Month)
    GroupsMapping = sort(dfDataGrouped.keymap, by = values)
    dfWeatherDistParameters = DataFrame(Month = [], hour = [],
                                        DistClearSky = [],
                                        PValueCvMTestClearSky = [],
                                        ratioClearSky = [])

    for PeriodNum in 1:12
        CurrentPeriod = GroupsMapping.vals[PeriodNum]
        dfCurrentPeriod = dfDataGrouped[CurrentPeriod]
        Month = PeriodNum

        for hour in 0:23
            dfCurrentHour = filter(row -> row.hour .== hour, dfCurrentPeriod)
            ratioClearSky = size(dfCurrentHour[dfCurrentHour.ClearSkyIndex.>0, :])[1] / size(dfCurrentHour)[1]
            println("Current month: $month, period: $PeriodNum , hour: $hour")
            println("Clear sky ratio is $ratioClearSky")
            if ratioClearSky < 0.5
                DistClearSky = nothing
                PValueCvMTestClearSky = nothing
            else
                if disttype == "weibull_min"
                    DistClearSky = st.weibull_min.fit(dfCurrentHour.ClearSkyIndex)
                elseif disttype == "beta"
                    DistClearSky = st.beta.fit(dfCurrentHour.ClearSkyIndex)
                else
                    println("Invalid type of distribution")
                    return nothing
                end
                PValueCvMTestClearSky = st.cramervonmises(
                    dfCurrentHour.ClearSkyIndex, disttype, args = (DistClearSky)
                ).pvalue
            end
            push!(dfWeatherDistParameters, (Month, hour,
                                            DistClearSky,
                                            PValueCvMTestClearSky,
                                            ratioClearSky)
            )
        end
    end
    return Dict(
        "dfWeatherDistParameters" => dfWeatherDistParameters,
        "dfDataGrouped" => dfDataGrouped
    )
end

abc = IrradiationDistributions(dfIrrDataFull)
abc["dfWeatherDistParameters"]
filter(row -> (!isnothing(row.PValueCvMTestClearSky)),
    abc["dfWeatherDistParameters"])
filter(row -> (!isnothing(row.PValueCvMTestClearSky) && row.PValueCvMTestClearSky < 0.05),
    abc["dfWeatherDistParameters"])

xyz = IrradiationDistributions(dfIrrDataFull, disttype = "beta")
xyz["dfWeatherDistParameters"]
filter(row -> (!isnothing(row.PValueCvMTestClearSky)),
    xyz["dfWeatherDistParameters"])
filter(row -> (!isnothing(row.PValueCvMTestClearSky) && row.PValueCvMTestClearSky < 0.05),
    xyz["dfWeatherDistParameters"])
