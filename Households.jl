using CSV, DataFrames, Dates, Pipe, Statistics
using Clustering, StatsPlots, Random
using FreqTables, Impute, Distances

cd("C:/Users/Marcel/Desktop/mgr/kody")
cMasterDir = "C:/Users/Marcel/Desktop/mgr/data/LdnHouseDataSplit"
AllHouseholdData = readdir(cMasterDir)
dfHouseholdData = DataFrames.DataFrame()

function ProcessHouseholdData(cMainDir, cFileName)
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

# append all the data together
for FileNum in 1:length(AllHouseholdData)
    println("File number ", FileNum, ", file name ", AllHouseholdData[FileNum])
    dfTemp = ProcessHouseholdData(cMasterDir, AllHouseholdData[FileNum])
    nrow(dfTemp) > 0 && append!(dfHouseholdData, dfTemp)
    dfTemp = DataFrames.DataFrame()
end

# Filter only data for 2013, create a date and time column
dfHouseholdDataShort = filter(row -> (row.Date > Dates.Date("2012-12-31") && row.Date < Dates.Date("2014-01-01")),
    dfHouseholdData)
dfHouseholdData = nothing

# FreqTableReadings = FreqTables.freqtable(dfHouseholdDataShort.LCLid, dfHouseholdDataShort.Date)
# m = [count(col.==24) for col in eachcol(FreqTableReadings)]
any(dfHouseholdDataShort.Consumption .< 0)

# choosing only households which have readings for each of the 365 days of 2013
# grouping the households by HouseholdID
# and selecting only those which have 365 unique dates in readings
dfHouseholdDataByHousehold = @pipe groupby(dfHouseholdDataShort, :LCLid)
iCompleteHouseholds = findall([length(unique(dfHouseholdDataByHousehold[i].Date)) for i in 1:length(dfHouseholdDataByHousehold)] .==365)
dfHouseholdDataCompleteHouseholds = dfHouseholdDataByHousehold[iCompleteHouseholds]
dfHouseholdDataShortCompleteDoubles = combine(dfHouseholdDataCompleteHouseholds,
    [:Date, :Hour, :Consumption])
iNonUniqueIndices = findall(nonunique(dfHouseholdDataShortCompleteDoubles[:,[:LCLid, :Date, :Hour]]).==true)

dfHouseholdDataShortComplete = @pipe groupby(dfHouseholdDataShortCompleteDoubles, [:LCLid, :Date, :Hour]) |>
    combine(_, :Consumption => mean => :Consumption)
iNonUniqueIndicesCorrected = findall(nonunique(dfHouseholdDataShortComplete[:,[:LCLid, :Date, :Hour]]).==true)

# Add a couple of columns
# dfHouseholdDataShortComplete.DateAndHour = DateTime.(dfHouseholdDataShortComplete.Date) .+ Dates.Hour.(dfHouseholdDataShortComplete.Hour)
dfHouseholdDataShortComplete.Month = Dates.month.(dfHouseholdDataShortComplete.Date)
dfHouseholdDataShortComplete.DayOfWeek = Dates.dayofweek.(dfHouseholdDataShortComplete.Date)


# Clear old dfs to release RAM
dfHouseholdDataByHousehold = nothing
iCompleteHouseholds = nothing
dfHouseholdDataCompleteHouseholds = nothing
dfHouseholdDataShort = nothing
dfHouseholdDataShortComplete.Month = Dates.month.(dfHouseholdDataShortComplete.Date)
dfHouseholdDataShortComplete.DayOfWeek = Dates.dayofweek.(dfHouseholdDataShortComplete.Date)

# unstack data to wide - needed for clustering
dfHouseholdDataFinal = unstack(dfHouseholdDataShortComplete, :LCLid, :Consumption)

# data imputation
for column in eachcol(dfHouseholdDataFinal)
    Impute.impute!(column, Impute.Interpolate())
    Impute.impute!(column, Impute.LOCF())
    Impute.impute!(column, Impute.NOCB())
end
disallowmissing!(dfHouseholdDataFinal)

# Clear old dfs to release RAM
dfHouseholdDataShortCompleteDoubles = nothing
dfHouseholdDataShortComplete = nothing

dfHouseholdDataByMonth = groupby(dfHouseholdDataFinal,
    [:Month, :DayOfWeek], sort = true)

c = @pipe groupby(dfHouseholdDataShortComplete, :LCLid) |>
    combine(_, [:Consumption => mean
                :Consumption => var
                :Consumption => minimum
                :Consumption => maximum])
Random.seed!(72945)
SelectedDays = (rand(1:12, 5), rand(1:7, 5))

TestSillhouettesOutput = Dict{}()

for testNumber in 1:5, NumberOfTestClusters in 2:7
    println("Month ", SelectedDays[1][testNumber], " , day ", SelectedDays[2][testNumber], ", number of clusters $NumberOfTestClusters" )
    CurrentPeriod = dfHouseholdDataByMonth[(SelectedDays[1][testNumber], SelectedDays[2][testNumber])]
    TestClusters = Clustering.kmeans(
        Matrix(CurrentPeriod[:,6:size(CurrentPeriod)[2]]), NumberOfTestClusters)
    TestSillhouettes = Clustering.silhouettes(TestClusters.assignments, TestClusters.counts,
            pairwise(SqEuclidean(), Matrix(CurrentPeriod[:,6:size(CurrentPeriod)[2]])))
    SilhouetteScore = mean(TestSillhouettes)
    push!(TestSillhouettesOutput, (SelectedDays[1][testNumber], SelectedDays[2][testNumber], NumberOfTestClusters) =>
        SilhouetteScore)
end

tempKeys = keys(TestSillhouettesOutput) |> collect
TestDays = [tempKeys[i][1:2] for i in 1:length(tempKeys)]
NumberOfClusters = [tempKeys[i][3] for i in 1:length(tempKeys)]
SillhouetteScore = convert.(Float64, values(TestSillhouettesOutput) |> collect)
dfToPlot = DataFrames.DataFrame(TestDays = TestDays, NumberOfClusters = NumberOfClusters,
    SillhouetteScore = SillhouetteScore)

fasfasd = @df dfToPlot StatsPlots.groupedbar(:NumberOfClusters, :SillhouetteScore,
    group = :TestDays,
    color = [RGB(192/255, 0, 0) RGB(146/255, 0, 0) RGB(100/255, 0, 0) RGB(54/255, 0, 0)],
    xlabel = "Number of clusters",
    ylabel = "Average silhouette score",
    legendtitle = "Test Day")

HouseholdProfiles = Dict{}()

for Month in 1:12, Day in 1:7
    println("Month ", Month, " , day ", Day)
    CurrentDayVols = dfHouseholdDataByMonth[(Month, Day)]
    ClustersOnDay = Clustering.kmeans(
        Matrix(CurrentDayVols[:,6:size(CurrentDayVols)[2]]), 2
    )
    push!(HouseholdProfiles, (Month, Day) => ClustersOnDay.centers)
end

PlotOfGivenCluster = @df dfHouseholdDataByMonth[(1,1)] StatsPlots.plot(:Hour,
    cols(6:ncol(dfHouseholdDataByMonth[(1,1)])),
    color = RGB(192/255,0,0), linealpha = 0.05,
    legend = :none)

plot!(HouseholdProfiles[(1,1)], color = RGB(192/255, 0, 0), linealpha = 0.7)

#a = @df JanMon StatsPlots.plot(:Hour, cols(2:3300), color = RGB(192/255,0,0),
#    legend = :none, linealpha = 0.05, ylim = (0,2),
#    title = "Short data, average daily profile")

# dfHouseholdDataByMonth[(SelectedDays[1][1], SelectedDays[2][1])]
#p = sort(repeat([i for i in 2:7], 3))
#t = [repeat(SelectedDays, 7) ]

#dfHouseholdDataByMonth[(SelectedDays[1,1], SelectedDays[1,2])]

#b = Iterators.product(SelectedDays, a) |> collect
#a = [2 3 4 5 6 7]'

a = dfHouseholdDataByMonth[(SelectedDays[1][1], SelectedDays[2][1])]
testProfiles = Clustering.kmeans(Matrix(a[:,6:size(a)[2]]), 5)
# pairwise(SqEuclidean(), Matrix(JanMon[:,6:size(JanMon)[2]]))
b = Clustering.silhouettes(testProfiles.assignments, testProfiles.counts,
    pairwise(SqEuclidean(), Matrix(a[:,6:size(a)[2]])))
mean(b)
testProfilesValues = testProfiles.centers
StatsPlots.plot!(test2.Hour, testProfilesValues, color = RGB(100/255, 100/255, 100/255),
    legend = :none, linealpha = 0.6, lw = 5)
