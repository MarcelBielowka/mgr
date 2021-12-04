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

    # Handling of the daylight saving time switch
    # We mvoe all the data to UTC + 1 to facilitate handling of all the data
    println("Some additional shenanigans for DSL switch")
    dfPriceDataRaw = ChangeHourToPlus1(dfPriceDataRaw)
    insertcols!(dfPriceDataRaw,
        :DeliveryMonth => Dates.month.(dfPriceDataRaw.DeliveryDate))

    # basic data validation - check if any data missing
    # and if all the days have all the hours
    println("Basic data validation")
    DateVsHour = freqtable(dfPriceDataRaw, :DeliveryDate, :DeliveryHour)
    @assert all(DateVsHour .== 1)
    @assert !any(ismissing.(dfPriceDataRaw.Price))

    dfPriceDataRaw = dfPriceDataRaw[2:nrow(dfPriceDataRaw),:]
    return dfPriceDataRaw
end

function ChangeHourToPlus1(dfPriceDataRaw)
    ForwardSwitchDate = Array{Date, 1}()
    BackwardSwitchDate = Array{Date, 1}()
    # recode the additional hour to 02:00
    dfPriceDataRaw.delivery_hour[dfPriceDataRaw.delivery_hour.=="02a"] .= "2"
    # find the change dates
    for i in 1:(DataFrames.nrow(dfPriceDataRaw)-1)
        if (dfPriceDataRaw.delivery_hour[i] == "1" && dfPriceDataRaw.delivery_hour[i+1] == "3")
            push!(ForwardSwitchDate, dfPriceDataRaw.delivery_date[i])
        end

        if (dfPriceDataRaw.delivery_hour[i] == "2" && dfPriceDataRaw.delivery_hour[i+1] == "2")
            push!(BackwardSwitchDate, dfPriceDataRaw.delivery_date[i])
        end
    end
    println("Forward switch dates: ", ForwardSwitchDate)
    println("Backward switch dates: ", BackwardSwitchDate)

    # recode the hours to integers from strings and change the formatting 1:24 to 0:23
    dfPriceDataRaw[!, "delivery_hour"] = parse.(Int64, dfPriceDataRaw[!, "delivery_hour"])
    dfPriceDataRaw.delivery_hour .-= 1
    dfPriceDataRaw.DeliveryDateAndHour = @pipe string.(dfPriceDataRaw.delivery_date, "T", dfPriceDataRaw.delivery_hour) |>
        Dates.DateTime.(_)

    # change the dates
    for i in 1:length(ForwardSwitchDate)
        println("Performing the switch for dates ", ForwardSwitchDate[i], " and ", BackwardSwitchDate[i])
        dfPriceDataRaw.DeliveryDateAndHour[(dfPriceDataRaw.delivery_date .> ForwardSwitchDate[i]) .&
            (dfPriceDataRaw.delivery_date .< BackwardSwitchDate[i])] .-= Dates.Hour(1)
        dfPriceDataRaw.DeliveryDateAndHour[(dfPriceDataRaw.delivery_date .== ForwardSwitchDate[i]) .&
            (dfPriceDataRaw.delivery_hour .>1)] .-= Dates.Hour(1)
        dfPriceDataRaw.DeliveryDateAndHour[(dfPriceDataRaw.delivery_date .== BackwardSwitchDate[i]) .&
            (dfPriceDataRaw.delivery_hour .<1)] .-= Dates.Hour(1)
    end

    for i in 1:(DataFrames.nrow(dfPriceDataRaw)-1)
        if (Dates.hour(dfPriceDataRaw.DeliveryDateAndHour[i]) == 23 && Dates.hour(dfPriceDataRaw.DeliveryDateAndHour[i+1]) == 1)
            dfPriceDataRaw.DeliveryDateAndHour[i+1] -= Dates.Hour(1)
        end
    end

    # Some additional formatting
    dfPriceDataRaw.DeliveryDate = Dates.Date.(dfPriceDataRaw.DeliveryDateAndHour)
    dfPriceDataRaw.DeliveryHour = Dates.hour.(dfPriceDataRaw.DeliveryDateAndHour)
    dfPriceDataRaw.DeliveryDayOfWeek = Dates.dayofweek.(dfPriceDataRaw.DeliveryDate)
    select!(dfPriceDataRaw, [:DeliveryDate, :DeliveryHour, :DeliveryDayOfWeek, :price, :delivery_date, :delivery_hour])
    rename!(dfPriceDataRaw, [:DeliveryDate, :DeliveryHour, :DeliveryDayOfWeek, :Price, :OriginalDeliveryDate, :OriginalDeliveryHour])
    return dfPriceDataRaw
end

#data = ReadPrices("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_20170101_20201014.csv")
#data = ReadPrices("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_20170101_20201014.csv",
#    DeliveryFilterStart = "2019-01-01")
#data = ReadPrices("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_20170101_20201014.csv",
#    DeliveryFilterEnd = "2018-12-31")
#data = ReadPrices("C:/Users/Marcel/Desktop/mgr/data/POLPX_DA_20170101_20201014.csv",
#    DeliveryFilterStart = "2019-01-01", DeliveryFilterEnd = "2019-12-31")
