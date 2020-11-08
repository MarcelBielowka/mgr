using CSV, DataFrames, Dates, Distributions
using HypothesisTests
using Plots, StatsBase, Turing
using FreqTables, Random
using HTTP, LightXML, Dates
include("ExtractFromApi.jl")

#########################################
#### Retrieving prices and load data ####
#########################################
function ReadPrices(cCsvDir; RemoveDSL = true, BaseNodeNameLoad = "quantity")
    # very basic data validation
    @assert typeof(RemoveDSL) == Bool
    # reading the price data, selecting (and renaming) only needed columns
    dfPriceDataRaw = CSV.File(cCsvDir) |> DataFrame
    dfPriceDataRaw = dfPriceDataRaw[:,
                ["data obrotu", "data dostawy", "godzina dostawy", "kurs fixingu I (PLN/MWh)"]]
    rename!(dfPriceDataRaw, ["trade_date", "delivery_date", "delivery_hour", "price"])

    # retrieving load data from ENTSO-E Transparency platform
    # using Transparency Restful API
    FirstAndLastDay = extrema(dfPriceDataRaw[:"delivery_date"])
    iLoadData = ExtractTimeSeriesFromEntsoApi(FirstAndLastDay[1], FirstAndLastDay[2], "quantity")
    dfPriceDataRaw[:, :load_forecast] = iLoadData

    # removing the additional hour from March and adding the missing hour for October
    # the hour is added as an average of the neighbouring two
    filter!(row -> (row."delivery_hour" != "02a" ),  dfPriceDataRaw)
    dfPriceDataRaw["delivery_hour"] = parse.(Int64, dfPriceDataRaw["delivery_hour"])
    if RemoveDSL == true
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

    # adding the daily variables
    dfPriceDataRaw[:Saturday] = Dates.dayofweek.(dfPriceDataRaw[:delivery_date]) .== 6
    dfPriceDataRaw[:Sunday] = Dates.dayofweek.(dfPriceDataRaw[:delivery_date]) .== 7
    dfPriceDataRaw[:Monday] = Dates.dayofweek.(dfPriceDataRaw[:delivery_date]) .== 1
    dfPriceDataRaw[:log_price] = log.(dfPriceDataRaw.price)
    dfPriceDataRaw[:log_load_forecast] = log.(dfPriceDataRaw.load_forecast)

    # basic data validation - check if any data missing
    # and if all the days have all the hours
    println("Basic data validation")
    DateVsHour = freqtable(dfPriceDataRaw, :delivery_date, :delivery_hour)
    @assert all(DateVsHour .== 1)
    @assert !any(ismissing.(dfPriceDataRaw.price))

    return dfPriceDataRaw
end

#########################################
### Validate the prices and load data ###
#########################################
function SplitDataPerHour(dfPriceDataRaw, EndDate, CalibrationWindow, LagOfADFTest)
    println("Select only one year and run ADF tests per each hour")
    StartDate = EndDate - Dates.Day(CalibrationWindow)
    println("Start date of the period: $StartDate")
    println("End date of the period: $EndDate")
    dfPriceDataTemp = dfPriceDataRaw[dfPriceDataRaw.delivery_date.>=StartDate,:]
    dfPriceDataTemp = dfPriceDataTemp[dfPriceDataTemp.delivery_date.<EndDate,:]
    # dfPriceDataTemp = dfPriceDataRaw[dfPriceDataRaw.delivery_date.<EndDate,:]
    dfPriceDataTemp[:centred_log_price] = dfPriceDataTemp[:log_price] .-
        mean(dfPriceDataTemp[:log_price])
    # split the day for sub-dataframes, one per each hour of the day
    dfPriceDataByHour = groupby(dfPriceDataTemp, :delivery_hour)

    # additionally ADF test for each hour
    for i in 1:length(dfPriceDataByHour)
        ADFTestPrice = HypothesisTests.ADFTest(dfPriceDataByHour[i]["log_price"], Symbol("constant"), LagOfADFTest)
        ADFTestPriceDiff = HypothesisTests.ADFTest(diff(dfPriceDataByHour[i]["log_price"]), Symbol("constant"), LagOfADFTest)
        ADFTestLoad = HypothesisTests.ADFTest(dfPriceDataByHour[i]["log_load_forecast"], Symbol("constant"), LagOfADFTest)
        ADFTestLoadDiff = HypothesisTests.ADFTest(diff(dfPriceDataByHour[i]["log_load_forecast"]), Symbol("constant"), LagOfADFTest)
        b = round(pvalue(ADFTestPrice), digits = 4)
        b_diff = round(pvalue(ADFTestPriceDiff), digits = 4)
        c = round(pvalue(ADFTestLoad), digits = 4)
        c_diff = round(pvalue(ADFTestLoadDiff), digits = 4)
        println("Hour $i, ADF test p-value price: $b, $b_diff, ADF test p-value load: $c, $c_diff")
        #@assert b<0.1
    end

    return dfPriceDataByHour
end


#########################################
####### Group price and load data #######
#########################################


#########################################
######### Very price modelling ##########
#########################################
#function RunPriceModelling

#end

# Examples
# cPriceDataDir = "C://Users//Marcel//Desktop//mgr//data//POLPX_DA_20190101_20201014.csv"
# dfPriceDataFull = ReadPrices(cPriceDataDir)
# dfTest = ReadPrices(cPriceDataDir, RemoveDSL = false)
# dfPriceDataClean = CleanPrices(dfPriceDataFull)
