using HTTP, LightXML, Dates, Plots

#########################################
###### Data extractor from ENTSO-E ######
##### Transparency Platfrom RestAPI #####
#########################################
function DataExtractorApi(HttpString, BaseNodeName)
    # initial request to API
    ApiRequest = HTTP.request("GET",HttpString)

    # extract the request's body and from there - the XML tree
    DataXMLBody = String(ApiRequest.body)
    DataTree = LightXML.parse_string(DataXMLBody)

    # Traverse the XML tree - crete the root and extract only time series
    DataTreeRoot = root(DataTree)
    DataArray = DataTreeRoot["TimeSeries"]

    BaseDataVector = zeros(0)

    for i in 1:1:length(DataArray)
        DataDayI = DataArray[i]["Period"][1]
        # DataDayI - all prices on day i

        # traverse the tree further
        # to particular data points
        # and extract only price data (child's name "price.amount")
        for DataDayChild in child_elements(DataDayI)
            for child in child_elements(DataDayChild)
                if name(child) == BaseNodeName
                    append!(BaseDataVector, parse(Float64, content(child)))
                end
            end
        end
    end
    return(BaseDataVector)
end


#########################################
#### Wrapper for the data extractor #####
#### As ENTSO-E Transparency RestAPI ####
####### returns =< 1 year of data #######
#########################################
function ExtractTimeSeriesFromEntsoApi(OverallPeriodStart, OverallPeriodEnd, BaseNodeName)
    # placeholder for price data
    # moving the end date one day forward so that the last day is also included
    @assert typeof(OverallPeriodStart) == Date
    @assert typeof(OverallPeriodEnd) == Date

    DataArrayNoDate = zeros(0)
    OverallPeriodEnd = OverallPeriodEnd + Dates.Day(1)

    # converting time horizon to hourly granularity and assembling all the dates
    CurrentPeriodStart = Dates.DateTime(OverallPeriodStart)
    CurrentPeriodEnd = Dates.DateTime(OverallPeriodEnd)

    # number of years within the analysis timeframe = number of API requests
    NumberOfApiQueries =
        ceil(Int,Dates.value(OverallPeriodEnd - OverallPeriodStart)/365)
    GeneralApiHttpQuery =
        "https://transparency.entsoe.eu/api?documentType=A65&processType=A01&OutBiddingZone_Domain=10YPL-AREA-----S&periodStart=yyyymmddhhmm&periodEnd=yyyymmddhhmm&securityToken=3c4152bc-42d0-4b2d-809c-3715d5d1c95d"

    #months with DST
    iMonthWithDST = [5 6 7 8 9 10]'

    for i in 1:NumberOfApiQueries
        # ENTSO APIs take only one year max
        # so we split the periods in separate queries
        # the end of period is either y+1 or the overall end
        CurrentPeriodEnd =
            min(Dates.DateTime(OverallPeriodEnd),
                Dates.DateTime(CurrentPeriodStart) + Dates.Millisecond(1000*60*60*24*365))

        # parsing the dates to strings - needed to API queries body
        CurrentPeriodStartString =
            Dates.format(CurrentPeriodStart - Dates.Millisecond(1000*60*60),
                "yyyymmddHHMM")

        # a shift of 1 hour for winter months, 2 hours for summer months
        if(any(iMonthWithDST.==month(CurrentPeriodEnd)))
            CurrentPeriodEndString =
                Dates.format(CurrentPeriodEnd - Dates.Millisecond(1000*60*120),
                    "yyyymmddHHMM")
        else
            CurrentPeriodEndString =
                Dates.format(CurrentPeriodEnd - Dates.Millisecond(1000*60*60),
                    "yyyymmddHHMM")
        end

        QuerySplit = split(GeneralApiHttpQuery, "yyyymmddhhmm")
        ApiHttpQuery = QuerySplit[1] * CurrentPeriodStartString *
            QuerySplit[2] * CurrentPeriodEndString * QuerySplit[3]
        println(ApiHttpQuery)

        # running the API query function
        CurrentPeriodPriceData = DataExtractorApi(ApiHttpQuery, BaseNodeName)
        append!(DataArrayNoDate, CurrentPeriodPriceData)

        # moving the next query period start one year forward
        CurrentPeriodStart = CurrentPeriodStart + Dates.Millisecond(1000*60*60*24*365)
    end

    # returning the result
    return DataArrayNoDate
end

# Examples
#aaa = ExtractTimeSeriesFromEntsoApi(Date("2020-07-10"), Date("2020-07-12"), "quantity")
