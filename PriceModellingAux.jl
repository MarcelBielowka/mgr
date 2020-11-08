using CSV, DataFrames, Plots, HypothesisTests, Dates

dfPriceDataRaw = CSV.File("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_all.csv") |>
    DataFrame

dfPriceDataRaw = dfPriceDataRaw[:,
                ["data obrotu", "data dostawy", "godzina dostawy", "kurs fixingu I (PLN/MWh)"]]
rename!(dfPriceDataRaw, ["trade_date", "delivery_date", "delivery_hour", "price"])

dfPriceDataRaw["log_price"] = log.(dfPriceDataRaw["price"])

a = dfPriceDataRaw[dfPriceDataRaw["delivery_hour"].=="9",:]
a = a[(1766-100):1766,:]
pvalue(HypothesisTests.ADFTest(a["log_price"], Symbol("none"), 8))
plot(a["delivery_date"], a["log_price"])
