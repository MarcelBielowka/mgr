###############################################
### Load packages and set initial variables ###
###############################################
using CSV, DataFrames, Dates, Pipe, Statistics
using Clustering, StatsPlots, Random
using FreqTables, Impute, Distances
cd("C:/Users/Marcel/Desktop/mgr/kody")
cMasterDir = "C:/Users/Marcel/Desktop/mgr/data/LdnHouseDataSplit"

FinalHouseholdData = GetHouseholdsData(cMasterDir)

###############################################
###### The very households weightlifting ######
###############################################

function GetHouseholdsData(cMasterDir; FixedSeed = 72945)
    dfHouseholdDataFull = ReadRawData(cMasterDir)
    println("Start processing data")
    # Filter only data for 2013
    println("Selecting data")
    dfHouseholdDataShort = filter(row -> (row.Date > Dates.Date("2012-12-31") && row.Date < Dates.Date("2014-01-01")),
        dfHouseholdDataFull)
    dfHouseholdDataFull = nothing

    if any(dfHouseholdDataShort.Consumption .< 0)
        println("Some households have consumption < 0. Execution stopped")
        return nothing
    else
        println("None of the households has consumption below 0. All is fine")
    end

    # Select only households with readings in each day of 2013
    # and remove duplicates
    dfHouseholdDataShortComplete = ClearAndModifyHouseholdData(dfHouseholdDataShort)[1]
    if isnothing(dfHouseholdDataShort)
        return nothing
    else
        println("None of the households has duplicated values. All is fine")
    end

    println("Splitting data by month and day of week")
    dfHouseholdDataToCluster = PrepareDataForClustering(dfHouseholdDataShortComplete)

    Random.seed!(FixedSeed)
    SelectedDays = (rand(1:12, 3), rand(1:7, 3))
    println("Days selected for test runs are $SelectedDays")
    TestClusteringData = RunTestClustering(dfHouseholdDataToCluster, SelectedDays)

    println("Running final clustering")
    FinalClusteringOutput = RunFinalClustering(dfHouseholdDataToCluster, TestClusteringData[2])

    println("Returning the figures")
    ClusteringOutput = Dict(
        "FinalClusteringOutput" => FinalClusteringOutput,
        "ClusteredData" => dfHouseholdDataToCluster,
        "SillhouettesScoreAverage" => TestClusteringData[1]
    )

    return ClusteringOutput
end

###############################################
########## Reading data from csv files ########
###############################################
function ReadRawData(cMasterDir)
    println("Start reading data")
    AllHouseholdData = readdir(cMasterDir)
    dfHouseholdData = DataFrames.DataFrame()

    # append all the data together
    for FileNum in 1:length(AllHouseholdData)
        println("File number ", FileNum, ", file name ", AllHouseholdData[FileNum])
        dfTemp = ProcessRawHouseholdData(cMasterDir, AllHouseholdData[FileNum])
        nrow(dfTemp) > 0 && append!(dfHouseholdData, dfTemp)
        dfTemp = DataFrames.DataFrame()
    end
    println("Extraction of data from csv finished. Moving to processing")
    return dfHouseholdData
end

###############################################
##### Choosing only data in time scope,  ######
######### adding columns and cleaning #########
###############################################
function ProcessRawHouseholdData(cMainDir, cFileName)
    # read file and rename columns
    dfAllData = CSV.File(string(cMainDir,"/",cFileName)) |>
        DataFrame
    rename!(dfAllData, [:LCLid, :stdorToU, :DateTime, :Consumption, :Acorn, :Acorn_grouped])
    # remove the affluent Londoners
    dfFilteredData = filter(row -> (row.stdorToU == "Std" && row.Consumption != "Null"),
                        dfAllData)

    # correct types - date time for date and Float for consumption
    dfFilteredData.DateTime = SubString.(dfFilteredData.DateTime,1,16)
    dfFilteredData.DateTime = Dates.DateTime.(dfFilteredData.DateTime,
                DateFormat("y-m-d H:M"))
    dfFilteredData.Consumption = parse.(Float64, dfFilteredData.Consumption)

    # grouping by date and hour
    dfFilteredData.Date = Dates.Date.(dfFilteredData.DateTime)
    dfFilteredData.Hour = Dates.hour.(dfFilteredData.DateTime)
    dfFilteredData_hourly = @pipe groupby(dfFilteredData, [:LCLid, :Date, :Hour]) |>
        combine(_, [:Consumption => sum => :Consumption])

    # returning
    return dfFilteredData_hourly
end

###############################################
####### Further cloeaning - see below #########
###############################################
# choosing only households which have readings for each of the 365 days of 2013
# grouping the households by HouseholdID
# and selecting only those which have 365 unique dates in readings
function ClearAndModifyHouseholdData(dfHouseholdData)
    # group by HID and select only those which have measurements for each day of the year,
    # then combine back
    dfHouseholdDataByHousehold = @pipe groupby(dfHouseholdData, :LCLid)
    iCompleteHouseholds = findall([length(unique(dfHouseholdDataByHousehold[i].Date)) for i in 1:length(dfHouseholdDataByHousehold)] .==365)
    dfHouseholdDataCompleteHouseholds = dfHouseholdDataByHousehold[iCompleteHouseholds]
    dfHouseholdDataShortCompleteDoubles = combine(dfHouseholdDataCompleteHouseholds,
        [:Date, :Hour, :Consumption])

    # check if there are some HID with duplicated readings on particular hours of particular days
    # if so, take the average
    iNonUniqueIndices = findall(nonunique(dfHouseholdDataShortCompleteDoubles[:,[:LCLid, :Date, :Hour]]).==true)
    dfHouseholdDataShortComplete = @pipe groupby(dfHouseholdDataShortCompleteDoubles, [:LCLid, :Date, :Hour]) |>
        combine(_, :Consumption => mean => :Consumption)
    iNonUniqueIndicesCorrected = findall(nonunique(dfHouseholdDataShortComplete[:,[:LCLid, :Date, :Hour]]).==true)
    # if after the combination there are still some douplicated numbers
    # break the functions
    if length(iNonUniqueIndicesCorrected) != 0
        println("There are some households with missing data. Execution stopped")
        return nothing
    end
    # Add month and day of week columns
    dfHouseholdDataShortComplete.Month = Dates.month.(dfHouseholdDataShortComplete.Date)
    dfHouseholdDataShortComplete.DayOfWeek = Dates.dayofweek.(dfHouseholdDataShortComplete.Date)

    # return the outcome
    return dfHouseholdDataShortComplete, iNonUniqueIndices
end

###############################################
####### Grouping data by month and day ########
################ for clustering ###############
###############################################
function PrepareDataForClustering(dfHouseholdData)
    dfHouseholdDataToCluster = deepcopy(dfHouseholdData)
    dfHouseholdDataToCluster.IDAndDay = string.(dfHouseholdDataToCluster.LCLid,
        dfHouseholdDataToCluster.Month, Dates.day.(dfHouseholdDataToCluster.Date))
    select!(dfHouseholdDataToCluster, Not([:LCLid, :Date]))
    dfHouseholdDataByMonth = @pipe groupby(dfHouseholdDataToCluster,
        [:Month, :DayOfWeek], sort = true)
    return dfHouseholdDataByMonth
end

###############################################
#### Transforming data to wide - see below ####
###############################################
# we need wide data for clustering
# due to memory overflows we can't transform them this way at once
# instead, we work with period by period
# additional point - data imputation
function PrepareDaysDataForClustering(dfHouseholdDataByMonth, CurrentMonth, CurrentDayOfWeek)
    CurrentPeriod = @pipe dfHouseholdDataByMonth[(CurrentMonth, CurrentDayOfWeek)] |>
        unstack(_, :IDAndDay, :Consumption)
    for column in eachcol(CurrentPeriod)
        Impute.impute!(column, Impute.Interpolate())
        Impute.impute!(column, Impute.LOCF())
        Impute.impute!(column, Impute.NOCB())
    end
    disallowmissing!(CurrentPeriod)
    return CurrentPeriod
end

###############################################
############### Test clustering ###############
###############################################
function RunTestClustering(dfHouseholdDataByMonth, SelectedDays)
    # placeholder for the output
    TestSillhouettesOutput = Dict{}()

    # loop over the test dates
    for testNumber in 1:length(SelectedDays[1]), NumberOfTestClusters in 2:7
        println("Month ", SelectedDays[1][testNumber], " , day ", SelectedDays[2][testNumber], ", number of clusters $NumberOfTestClusters" )
        # get data in wide format
        CurrentPeriod = PrepareDaysDataForClustering(dfHouseholdDataByMonth,
            SelectedDays[1][testNumber], SelectedDays[2][testNumber])
        # run clustering
        TestClusters = Clustering.kmeans(
            Matrix(CurrentPeriod[:,4:size(CurrentPeriod)[2]]), NumberOfTestClusters)
        # silhouettes
        TestSillhouettes = Clustering.silhouettes(TestClusters.assignments, TestClusters.counts,
                pairwise(
                    Euclidean(), Matrix(CurrentPeriod[:,4:size(CurrentPeriod)[2]]),
                dims = 2)
            )
        # final score
        SilhouetteScore = mean(TestSillhouettes)
        push!(TestSillhouettesOutput, (SelectedDays[1][testNumber], SelectedDays[2][testNumber], NumberOfTestClusters) =>
            SilhouetteScore)
    end

    # getting the data to the output data frame
    tempKeys = keys(TestSillhouettesOutput) |> collect
    TestDays = [tempKeys[i][1:2] for i in 1:length(tempKeys)]
    NumberOfClusters = [tempKeys[i][3] for i in 1:length(tempKeys)]
    SillhouetteScore = convert.(Float64, values(TestSillhouettesOutput) |> collect)
    dfSillhouettesOutcome = DataFrames.DataFrame(TestDays = TestDays, NumberOfClusters = NumberOfClusters,
        SillhouetteScore = SillhouetteScore)
    dfSillhouettesOutcomeAverage = @pipe groupby(dfSillhouettesOutcome, :NumberOfClusters) |>
        combine(_, :SillhouetteScore => mean => :SillhouetteScoreAvg)
    FinalNumberOfClusters = dfSillhouettesOutcomeAverage.NumberOfClusters[
        dfSillhouettesOutcomeAverage.SillhouetteScoreAvg .== maximum(dfSillhouettesOutcomeAverage.SillhouetteScoreAvg),1][1]

    println("The optimal number of clusters is $FinalNumberOfClusters")
    return dfSillhouettesOutcome, FinalNumberOfClusters
end

###############################################
############## Final clustering ###############
###############################################
function RunFinalClustering(dfHouseholdDataByMonth, OptimalNumberOfClusters)
    # the function runs just like above
    HouseholdProfiles = Dict{}()
    for Month in 1:12, Day in 1:7
        println("Month ", Month, " , day ", Day)
        CurrentPeriod = PrepareDaysDataForClustering(dfHouseholdDataByMonth,
            Month, Day)
        ClustersOnDay = Clustering.kmeans(
            Matrix(CurrentPeriod[:,4:size(CurrentPeriod)[2]]), OptimalNumberOfClusters
        )
        dfClusteringOutput = hcat(CurrentPeriod.Hour, ClustersOnDay.centers) |> DataFrame
        rename!(dfClusteringOutput,
            vcat("Hour", [string("Profile", i) for i in 1:OptimalNumberOfClusters])
        )
        dfClusteringOutput.Hour = convert.(Int, dfClusteringOutput.Hour)

        push!(HouseholdProfiles, (Month, Day) => dfClusteringOutput)
    end

    return HouseholdProfiles
end

###############################################
#################### Plots ####################
###############################################
plotSillhouettes = @df FinalHouseholdData["SillhouettesScoreAverage"] StatsPlots.groupedbar(:NumberOfClusters, :SillhouetteScore,
    group = :TestDays,
    color = [RGB(192/255, 0, 0) RGB(100/255, 0, 0) RGB(8/255, 0, 0)],
    xlabel = "Number of clusters",
    ylabel = "Average silhouette score",
    legendtitle = "Test Day")

#######
dfWideDataToPlotJanMon = PrepareDaysDataForClustering(FinalHouseholdData["ClusteredData"],1,1)
dfWideDataToPlotJulMon = PrepareDaysDataForClustering(FinalHouseholdData["ClusteredData"],7,1)
dfWideDataToPlotJanSun = PrepareDaysDataForClustering(FinalHouseholdData["ClusteredData"],1,7)

#January Mondays plot
PlotOfClusterJanMon = @df dfWideDataToPlotJanMon StatsPlots.plot(:Hour,
    cols(4:3000),
    color = RGB(150/255,150/255,150/255), linealpha = 0.05,
    legend = :none,
    ylim = [0,5],
    main = "January Monday")
@df FinalHouseholdData["FinalClusteringOutput"][(1,1)] StatsPlots.plot!(:Hour,
    cols(2:ncol(FinalHouseholdData["FinalClusteringOutput"][(1,1)])),
    color = RGB(192/255,0,0), linealpha = 0.5, lw = 2)

PlotOfClusterJanSun = @df dfWideDataToPlotJanSun StatsPlots.plot(:Hour,
    cols(4:3000),
    color = RGB(150/255,150/255,150/255), linealpha = 0.05,
    legend = :none,
    ylim = [0,5],
    main = "January Sunday")
@df FinalHouseholdData["FinalClusteringOutput"][(1,7)] StatsPlots.plot!(:Hour,
    cols(2:ncol(FinalHouseholdData["FinalClusteringOutput"][(1,7)])),
    color = RGB(192/255,0,0), linealpha = 0.5, lw = 2)

PlotOfClusterJulMon = @df dfWideDataToPlotJulMon StatsPlots.plot(:Hour,
    cols(4:3000),
    color = RGB(150/255,150/255,150/255), linealpha = 0.05,
    legend = :none,
    ylim = [0,5],
    main = "July Monday")
@df FinalHouseholdData["FinalClusteringOutput"][(7,1)] StatsPlots.plot!(:Hour,
    cols(2:ncol(FinalHouseholdData["FinalClusteringOutput"][(7,1)])),
    color = RGB(192/255,0,0), linealpha = 0.5, lw = 2)
