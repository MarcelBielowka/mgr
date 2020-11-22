using CSV, DataFrames, Plots, Dates, Distributions, Random, StatsPlots
using HypothesisTests, RCall, Pipe, Statistics
using Suppressor

# reading data, extracting dates
dfWeatherDataSampleAll = CSV.File("C:/Users/Marcel/Desktop/mgr/data/weather_data_sample.csv") |>
    DataFrame
dfWeatherDataSampleAll["date"] =
    Dates.DateTime.(dfWeatherDataSampleAll["date"], DateFormat("y-m-d H:M"))
dfWeatherDataSampleAll["date_nohour"] = Dates.Date.(dfWeatherDataSampleAll["date"])
dfWeatherDataSampleAll["month"] = Dates.month.(dfWeatherDataSampleAll["date"])
dfWeatherDataSampleAll["hour"] = Dates.hour.(dfWeatherDataSampleAll["date"])

plot(dfWeatherDataSampleAll[:date],dfWeatherDataSampleAll[:promieniowanie_Wm2])
plot(dfWeatherDataSampleAll[:date],dfWeatherDataSampleAll[:predkosc100m])


## extracting data, selecting only necessary
# and taking hourly averages
miss = dfWeatherDataSampleAll[ismissing.(dfWeatherDataSampleAll.promieniowanie_Wm2),:]
dfWeatherDataSample = dfWeatherDataSampleAll[completecases(dfWeatherDataSampleAll),:]

## wind data
SubsampleS1 = dfWeatherDataSample[dfWeatherDataSample.month.<10,:]
SubsampleS1 = SubsampleS1[SubsampleS1.month.>6,:]
SubsampleS1_h = @pipe groupby(SubsampleS1, [:date_nohour, :hour]) |>
                    combine(_, [:predkosc100m => mean => :predkosc100m,
                            :promieniowanie_Wm2 => mean => :promieniowanie_Wm2])
# Weibull dsitribution fitting
h = 13
@rlibrary MASS
DistWindMASS = fitdistr(SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==h], "weibull")
DistWind = Distributions.Weibull(DistWindMASS[1][1], DistWindMASS[1][2])
# KS test of fit goodness
KS = HypothesisTests.ExactOneSampleKSTest(SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==h], DistWind)
HypothesisTests.ApproximateOneSampleKSTest(SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==14], DistWind)

# histogram and QQplots
StatsPlots.histogram(SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==h], normalize = true)
plot!(DistWind,lw = 5, color =:red)
plot(
 qqplot(DistWind, SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==h])
)

Random.seed!(72945)
SampleWindSpeed = [mean(rand(DistWind, 1000)) for i in 1:100000]
StatsPlots.histogram(SampleWindSpeed)

ConfInt = quantile!(SampleWindSpeed, [0.025, 0.0975])
diff(ConfInt)

## solar irradiation distribution - fitting Weibull as well
h = 10
# temp = filter(row -> (row.promieniowanie_Wm2>0), SubsampleS1_h)
temp = filter(row -> (row.hour == h && row.promieniowanie_Wm2>0) , SubsampleS1_h )
#promieniowanie_ex = extrema(temp.promieniowanie_Wm2)
#temp[:promieniowanie_unit] = (temp.promieniowanie_Wm2 .- promieniowanie_ex[1]) ./ (promieniowanie_ex[2] - promieniowanie_ex[1])

# unitarisation - as per Lv at all (2)
# DistSolarMASS = fitdistr(temp.promieniowanie_unit, "beta", start = (R"list(shape1 = 4,shape2 = 2)"))
DistSolarMASS = fitdistr(temp.promieniowanie_Wm2, "weibull")
DistSolarMASS = fitdistr(temp.promieniowanie_Wm2, "Weibull", lower = "c(0,0)")

# DistSolar = Distributions.Beta(DistSolarMASS[1][1], DistSolarMASS[1][2])
DistSolar = Distributions.Weibull(DistSolarMASS[1][1], DistSolarMASS[1][2])

# plotting histogram and QQplot
StatsPlots.histogram(temp.promieniowanie_Wm2, normalize = true)
plot!(DistSolar,lw = 5, color =:red)
plot(
 qqplot(DistSolar, temp.promieniowanie_Wm2)
)

# KS test of goodness of fit
HypothesisTests.ExactOneSampleKSTest(temp.promieniowanie_Wm2, DistSolar)

Random.seed!(72945)
SampleTotalIrr = [mean(rand(DistSolar, 1000)) for i in 1:100000]
StatsPlots.histogram(SampleTotalIrr)

## production functions
function WindProductionForecast(P_nam, V, V_nam, V_cutin, V_cutoff)
    if V < V_cutin
        P_output = 0
    elseif V >= V_cutin && V < V_nam
        P_output = ((V - V_cutin) ^ 3) / -((V_cutin - V_nam)^3)
    elseif V >= V_nam && V < V_cutoff
        P_output = P_nam
    else
        P_output = 0
    end
    return P_output
end

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




## sampling and forecasting
Random.seed!(72945)
SampledWindSpeed = rand(DistWind, 10000)
SampledSolarIrradiance = rand(DistSolar, 10000)

ForecastWindProd = WindProductionForecast.(2.0, SampledWindSpeed, 11.5, 3.0, 20.0)
PointForecast = mean(ForecastWindProd[ForecastWindProd.>0])
PointForecast = mean(ForecastWindProd[ForecastWindProd.>0.05])
histogram(ForecastWind[ForecastWindProd.>0.05])
histogram(ForecastWind[ForecastWindProd.>0])

CSV.write("C:/Users/Marcel/Desktop/mgr/data/grouped.csv", temp)
