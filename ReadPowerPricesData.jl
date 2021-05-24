using CSV, DataFrames, Dates
using StatsPlots, StatsBase
using FreqTables, Random

function ReadPrices(cFilePrices::String; DeliveryFilterStart = nothing, DeliveryFilterEnd = nothing, RemoveDSL = true)
    # reading the price data, selecting (and renaming) only needed columns
    dfPriceDataRaw = CSV.File(cFilePrices) |> DataFrame
    dfPriceDataRaw = dfPriceDataRaw[:,
                ["data obrotu", "data dostawy", "godzina dostawy", "kurs fixingu I (PLN/MWh)"]]
    rename!(dfPriceDataRaw, ["trade_date", "delivery_date", "delivery_hour", "price"])

    if !isnothing(DeliveryFilterStart)
        filter!(row -> row.delivery_date >= Dates.Date(DeliveryFilterStart), dfPriceDataRaw)
    end
    if !isnothing(DeliveryFilterEnd)
        StringEndDate = DeliveryFilterEnd * "T23:59:00"
        filter!(row -> row.delivery_date <= Dates.DateTime(StringEndDate), dfPriceDataRaw)
    end

    # removing the additional hour from March and adding the missing hour for October
    # the hour is added as an average of the neighbouring two
    filter!(row -> (row."delivery_hour" != "02a" ),  dfPriceDataRaw)
    dfPriceDataRaw[!, "delivery_hour"] = parse.(Int64, dfPriceDataRaw[!, "delivery_hour"])
    if RemoveDSL
        println("Adding additional hour for DSL switch")
        for i in 2:DataFrames.nrow(dfPriceDataRaw)
            if dfPriceDataRaw[i - 1,"delivery_hour"] == 1 && dfPriceDataRaw[i,"delivery_hour"] == 3
                println("DSL switch found for dates: ", dfPriceDataRaw[i,"delivery_date"])
                TempAddRow = DataFrame(trade_date = dfPriceDataRaw[i, "trade_date"],
                                       delivery_date = dfPriceDataRaw[i, "delivery_date"],
                                       delivery_hour = 2,
                                       price = (dfPriceDataRaw[i, "price"] + dfPriceDataRaw[i-1, "price"])/2)
                append!(dfPriceDataRaw, TempAddRow)
            end
        end
        sort!(dfPriceDataRaw, ["delivery_date", "delivery_hour"])
    else
        println("Adding additonal hour for DSL is skipped")
    end

    dfPriceDataRaw.delivery_hour .-= 1

    # basic data validation - check if any data missing
    # and if all the days have all the hours
    println("Basic data validation")
    DateVsHour = freqtable(dfPriceDataRaw, :delivery_date, :delivery_hour)
    @assert all(DateVsHour .== 1)
    @assert !any(ismissing.(dfPriceDataRaw.price))

    return dfPriceDataRaw
end

#data = ReadPrices("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_20170101_20201014.csv")
#data = ReadPrices("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_20170101_20201014.csv",
#    DeliveryFilterStart = "2019-01-01")
#data = ReadPrices("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_20170101_20201014.csv",
#    DeliveryFilterEnd = "2018-12-31")
#data = ReadPrices("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_20170101_20201014.csv",
#    DeliveryFilterStart = "2019-01-01", DeliveryFilterEnd = "2019-12-31")
