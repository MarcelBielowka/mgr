using CSV, DataFrames, Dates
using StatsPlots, StatsBase
using FreqTables, Random

function ReadPrices(cFilePrices::String; RemoveDSL = true)
    # reading the price data, selecting (and renaming) only needed columns
    dfPriceDataRaw = CSV.File(cFilePrices) |> DataFrame
    dfPriceDataRaw = dfPriceDataRaw[:,
                ["data obrotu", "data dostawy", "godzina dostawy", "kurs fixingu I (PLN/MWh)"]]
    rename!(dfPriceDataRaw, ["trade_date", "delivery_date", "delivery_hour", "price"])

    # removing the additional hour from March and adding the missing hour for October
    # the hour is added as an average of the neighbouring two
    filter!(row -> (row."delivery_hour" != "02a" ),  dfPriceDataRaw)
    dfPriceDataRaw["delivery_hour"] = parse.(Int64, dfPriceDataRaw["delivery_hour"])
    if RemoveDSL
        println("Adding additional hour for DSL switch")
        for i in 2:DataFrames.nrow(dfPriceDataRaw)
            if dfPriceDataRaw[i - 1,"delivery_hour"] == 1 && dfPriceDataRaw[i,"delivery_hour"] == 3
                println("DSL switch found for dates: ", dfPriceDataRaw[i,"delivery_date"])
                TempAddRow = DataFrame(trade_date = dfPriceDataRaw[i, "trade_date"],
                                       delivery_date = dfPriceDataRaw[i, "delivery_date"],
                                       delivery_hour = 2,
                                       price = (dfPriceDataRaw[i, "price"] + dfPriceDataRaw[i-1, "price"])/2,
                                       load_forecast = (dfPriceDataRaw[i, "load_forecast"] + dfPriceDataRaw[i-1, "load_forecast"])/2)
                append!(dfPriceDataRaw, TempAddRow)
            end
        end
        sort!(dfPriceDataRaw, ["delivery_date", "delivery_hour"])
    else
        println("Adding additonal hour for DSL is skipped")
    end

    # basic data validation - check if any data missing
    # and if all the days have all the hours
    println("Basic data validation")
    DateVsHour = freqtable(dfPriceDataRaw, :delivery_date, :delivery_hour)
    @assert all(DateVsHour .== 1)
    @assert !any(ismissing.(dfPriceDataRaw.price))

    return dfPriceDataRaw
end
