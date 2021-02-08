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

DistWindMASS = fitdistr(SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==1], "gamma")
DistWindMASS[4]
DistWind = fit_mle(Gamma, SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==1])
DistWind = Distributions.Gamma(DistWindMASS[1][1], DistWindMASS[1][2])

temp = filter(row -> row.predkosc100m > 0, SubsampleS1_h[SubsampleS1_h.hour.==1,:])
DistWindMASS = fitdistr(temp.predkosc100m, "weibull")
DistWindMASS[4]
DistWind = Distributions.Weibull(DistWindMASS[1][1], DistWindMASS[1][2])

@rlibrary MASS
for h in extrema(unique(SubsampleS1_h.hour))[1]:1:extrema(unique(SubsampleS1_h.hour))[2]
    println(h)
    DistWindMASS = fitdistr(SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==h], "weibull")
    DistWind = Distributions.Weibull(DistWindMASS[1][1], DistWindMASS[1][2])
    # KS test of fit goodness
    KSTest = @suppress HypothesisTests.ExactOneSampleKSTest(SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==h], DistWind)
    PValue = pvalue(KSTest)
    println("Hour $h, wind speed dist: Weibull, p-value for K-S Test: $PValue")

    # HypothesisTests.ApproximateOneSampleKSTest(SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==14], DistWind)
end


# histogram and QQplots
StatsPlots.histogram(SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==1], normalize = true)
plot!(DistWind,lw = 5, color =:red)
plot(
 qqplot(DistWind, SubsampleS1_h.predkosc100m[SubsampleS1_h.hour.==1])
)


## solar irradiation distribution - fitting Weibull as well
for h in extrema(unique(SubsampleS1_h.hour))[1]:1:extrema(unique(SubsampleS1_h.hour))[2]
    temp = SubsampleS1_h[SubsampleS1_h.promieniowanie_Wm2.>0,:]
    DistSolarMASSWeibull = fitdistr(temp.promieniowanie_Wm2[temp.hour.==h], "weibull",
        lower = "c(0,0)")
    DistSolarMASSNormal = fitdistr(temp.promieniowanie_Wm2[temp.hour.==h], "normal",
        lower = "c(0,0)")
    DistSolar = Distributions.Normal(DistSolarMASS[1][1], DistSolarMASS[1][2])

    KSTest = @suppress HypothesisTests.ExactOneSampleKSTest(temp.promieniowanie_Wm2[temp.hour.==h], DistSolar)
    PValue = pvalue(KSTest)
    println("Hour $h, solar irradiance dist: Weibull, p-value for K-S Test: $PValue")

end

temp = SubsampleS1_h.promieniowanie_Wm2[SubsampleS1_h.hour.==16]
temp2 = temp./(maximum(temp))

DistSolar = fit_mle(Normal, SubsampleS1_h.promieniowanie_Wm2[SubsampleS1_h.hour.==16])

DistSolarMASS = fitdistr(temp2, "beta", start = R"list(shape1 = 4, shape2 = 2)")
DistSolarMASS = fitdistr(temp, "beta", start = R"list(shape1 = 1000, shape2 = 2)")

# plotting histogram and QQplot
StatsPlots.histogram(SubsampleS1_h.promieniowanie_Wm2[SubsampleS1_h.hour.==16], normalize = true)
plot!(DistSolar,lw = 5, color =:red)
plot(
 qqplot(DistSolar, SubsampleS1_h.promieniowanie_Wm2[SubsampleS1_h.hour.==16])
)

# KS test of goodness of fit


## production functions
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
