using CSV, DataFrames, Plots, Dates, Distributions, Random, StatsPlots
using HypothesisTests, RCall, Pipe, Statistics
using Suppressor

# reading data, extracting dates
dfWeatherDataSample = CSV.File("C:/Users/Marcel/Desktop/mgr/data/weather_data_sample.csv") |>
    DataFrame
dfWeatherDataSample["date"] =
    Dates.DateTime.(dfWeatherDataSample["date"], DateFormat("y-m-d H:M"))
dfWeatherDataSample["date_nohour"] = Dates.Date.(dfWeatherDataSample["date"])
dfWeatherDataSample["month"] = Dates.month.(dfWeatherDataSample["date"])
dfWeatherDataSample["hour"] = Dates.hour.(dfWeatherDataSample["date"])


## extracting data, selecting only necessary
# and taking hourly averages
dfWeatherDataSample[ismissing.(dfWeatherDataSample.promieniowanie_Wm2),:]
dfWeatherDataSample[ismissing.(dfWeatherDataSample.promieniowanie_Wm2),"promieniowanie_Wm2"] = 0

## wind data
SubsampleS1 = dfWeatherDataSample[dfWeatherDataSample.month.<10,:]
SubsampleS1 = SubsampleS1[SubsampleS1.month.>6,:]
SubsampleS1_h = @pipe groupby(SubsampleS1, [:date_nohour, :hour]) |>
                    combine(_, [:predkosc100m => mean => :predkosc100m,
                            :promieniowanie_Wm2 => mean => :promieniowanie_Wm2])
# Weibull dsitribution fitting
h = 14
@rlibrary MASS
DistWindMASS = fitdistr(SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==h], "weibull")
DistWind = Distributions.Weibull(DistWindMASS[1][1], DistWindMASS[1][2])
# KS test of fit goodness
@suppress KS = HypothesisTests.ExactOneSampleKSTest(SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==h], DistWind)
HypothesisTests.ApproximateOneSampleKSTest(SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==14], DistWind)

# histogram and QQplots
StatsPlots.histogram(SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==h], normalize = true)
plot!(DistWind,lw = 5, color =:red)
plot(
 qqplot(DistWind, SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==h])
)


## solar irradiation distribution - fitting Weibull as well
h = 16
temp = SubsampleS1_h[SubsampleS1_h.promieniowanie_Wm2.>0,:]
DistSolarMASS = fitdistr(temp.promieniowanie_Wm2[temp.hour.==h], "Weibull", lower = "c(0,0)")
DistSolarMASS[4]
DistSolar = Distributions.Weibull(DistSolarMASS[1][1], DistSolarMASS[1][2])

# plotting histogram and QQplot
StatsPlots.histogram(temp.promieniowanie_Wm2[temp.hour.==h], normalize = true)
plot!(DistSolar,lw = 5, color =:red)
plot(
 qqplot(DistSolar, temp.promieniowanie_Wm2[temp.hour.==h])
)

# KS test of goodness of fit
HypothesisTests.ExactOneSampleKSTest(temp.promieniowanie_Wm2[temp.hour.==h], DistSolar)
HypothesisTests.ApproximateOneSampleKSTest(temp.promieniowanie_Wm2[temp.hour.==17], DistSolar)


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




## sampling
Random.seed!(72945)
SampledWindSpeed = rand(DistWind, 1000)
SampledSolarIrradiance = rand(DistSolar, 1000)

ForecastWind = WindProductionForecast.(2.0, SampledWindSpeed, 11.5, 3.0, 20.0)
histogram(ForecastWind)
