using CSV, DataFrames, Plots, HypothesisTests, Dates,
using StatsBase, LinearAlgebra, RCall

dfPriceDataRaw = CSV.File("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_all.csv") |>
    DataFrame

dfPriceDataRaw = dfPriceDataRaw[:,
                ["data obrotu", "data dostawy", "godzina dostawy", "kurs fixingu I (PLN/MWh)"]]
rename!(dfPriceDataRaw, ["trade_date", "delivery_date", "delivery_hour", "price"])

dfPriceDataRaw["log_price"] = log.(dfPriceDataRaw["price"])

Subsample_price = dfPriceDataRaw[dfPriceDataRaw.delivery_date.<Dates.Date("2018-01-01", DateFormat("y-m-d")),:]
Subsample_price = dfPriceDataRaw[dfPriceDataRaw.delivery_date.>=Dates.Date("2018-01-01", DateFormat("y-m-d")),:]
Subsample_price = Subsample_price[Subsample_price.delivery_date.<Dates.Date("2020-01-01", DateFormat("y-m-d")),:]
a = Subsample_price[Subsample_price["delivery_hour"].=="6",:]

HypothesisTests.ADFTest(Subsample_price.price, Symbol("constant"), 500)
HypothesisTests.ADFTest(Subsample_price.price, Symbol("trend"), 500)
HypothesisTests.ADFTest(Subsample_price.price, Symbol("squared_trend"), 500)

HypothesisTests.ADFTest(a["price"], Symbol("constant"), 40)
HypothesisTests.ADFTest(a["price"], Symbol("trend"), 40)
HypothesisTests.ADFTest(a["price"], Symbol("squared_trend"), 40)

HypothesisTests.ADFTest(diff(a["price"]), Symbol("constant"), 40)
HypothesisTests.ADFTest(diff(a["price"]), Symbol("trend"), 40)
HypothesisTests.ADFTest(diff(a["price"]), Symbol("squared_trend"), 40)

@rlibrary stats
R"acf"(diff(a.log_price), lag = 28)
R"acf"(a.log_price, lag = 50)
R"pacf"(diff(a.log_price), lag = 40)
R"pacf"(a.log_price, lag = 50)

R"acf"(Subsample_price.log_price, lag = 337)
R"pacf"(Subsample_price.log_price, lag = 336)

PriceModel = R"arima"(a.log_price, order = R"c(28,1,0)")

# plot(a.delivery_date[2:361], diff(a.log_price))
plot(a.delivery_date, a.price)
plot(a.delivery_date[2:end], diff(log.(a.price)))
plot(Subsample_price.delivery_date, Subsample_price.price)

Dates.Date("2018-01-01", DateFormat("y-m-d"))
