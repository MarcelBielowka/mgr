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
HypothesisTests.ADFTest(dfIrrDataFull.ClearSkyIndex, :constant, 24)
HypothesisTests.ADFTest(dfIrrDataFull.I_global_horizontal, :constant, 24)


function IrradiationDistributions(dfWeatherData)
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
                DistClearSky = st.weibull_min.fit(dfCurrentHour.ClearSkyIndex)
                PValueCvMTestClearSky = st.cramervonmises(
                    dfCurrentHour.ClearSkyIndex, "weibull_min", args = (DistClearSky)
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
abc = Juno.@enter IrradiationDistributions(dfIrrDataFull)
abc["dfWeatherDistParameters"]
filter(row -> (!isnothing(row.PValueCvMTestClearSky) && row.PValueCvMTestClearSky < 0.05),
    abc["dfWeatherDistParameters"])
