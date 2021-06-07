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
    println("Some additional shenanigans for DSL switch")
    dfPriceDataRaw = ChangeHourToPlus1(dfPriceDataRaw)
#    sort!(dfPriceDataRaw, ["delivery_date", "delivery_hour"])

    # basic data validation - check if any data missing
    # and if all the days have all the hours
#    println("Basic data validation")
#    DateVsHour = freqtable(dfPriceDataRaw, :delivery_date, :delivery_hour)
#    @assert all(DateVsHour .== 1)
#    @assert !any(ismissing.(dfPriceDataRaw.price))

    return dfPriceDataRaw
end

function ChangeHourToPlus1(dfPriceDataRaw)
    ForwardSwitchDate = Array{Date, 1}()
    BackwardSwitchDate = dfPriceDataRaw.delivery_date[dfPriceDataRaw.delivery_hour.=="02a"]
    for i in 1:(DataFrames.nrow(dfPriceDataRaw)-1)
        if (dfPriceDataRaw.delivery_hour[i] == "1" && dfPriceDataRaw.delivery_hour[i+1] == "3")
            push!(ForwardSwitchDate, dfPriceDataRaw.delivery_date[i])
        end
    end
    println("Forward switch dates: ", ForwardSwitchDate)
    println("Backward switch dates: ", BackwardSwitchDate)

    dfPriceDataRaw.delivery_hour[dfPriceDataRaw.delivery_hour.=="02a"] .= "-99"
    dfPriceDataRaw[!, "delivery_hour"] = parse.(Int64, dfPriceDataRaw[!, "delivery_hour"])
    #dfPriceDataRaw.delivery_hour .-= 1

    for i in 1:length(ForwardSwitchDate)
        println("Performing the switch for dates ", ForwardSwitchDate[i], " and ", BackwardSwitchDate[i])
        dfPriceDataRaw.delivery_hour[(dfPriceDataRaw.delivery_date .> ForwardSwitchDate[i]) .&
            (dfPriceDataRaw.delivery_date .< BackwardSwitchDate[i])] .-=1
        dfPriceDataRaw.delivery_hour[(dfPriceDataRaw.delivery_date .== ForwardSwitchDate[i]) .&
            (dfPriceDataRaw.delivery_hour .>3)] .-=1
        dfPriceDataRaw.delivery_hour[(dfPriceDataRaw.delivery_date .== BackwardSwitchDate[i]) .&
            (dfPriceDataRaw.delivery_hour .<3)] .-=1
    end

    dfPriceDataRaw.delivery_hour[dfPriceDataRaw.delivery_hour.==-101] .= 2

    return dfPriceDataRaw
end

#data = ReadPrices("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_20170101_20201014.csv")
#data = ReadPrices("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_20170101_20201014.csv",
#    DeliveryFilterStart = "2019-01-01")
#data = ReadPrices("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_20170101_20201014.csv",
#    DeliveryFilterEnd = "2018-12-31")
#data = ReadPrices("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_20170101_20201014.csv",
#    DeliveryFilterStart = "2019-01-01", DeliveryFilterEnd = "2019-12-31")
