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

dfHouseholdData.DateAndHour = DateTime.(dfHouseholdData.Date) .+ Dates.Hour.(dfHouseholdData.Hour)
dfHouseholdDataShort = filter(row -> (row.Date > Dates.Date("2012-12-31") && row.Date < Dates.Date("2014-01-01")),
    dfHouseholdData)
dfHouseholdData = nothing

FreqTableReadings = FreqTables.freqtable(dfHouseholdDataShort.LCLid, dfHouseholdDataShort.Date)
m = [count(col.==24) for col in eachcol(FreqTableReadings)]
any(dfHouseholdDataShort.Consumption .< 0)

dfHouseholdDataByHousehold = @pipe groupby(dfHouseholdDataShort, :LCLid)
iCompleteHouseholds = findall([length(unique(dfHouseholdDataByHousehold[i].Date)) for i in 1:length(dfHouseholdDataByHousehold)] .==365)
# iCompleteHouseholds = findall([nrow(dfHouseholdDataByHousehold[i]) for i in 1:length(dfHouseholdDataByHousehold)] .==8760)
dfHouseholdDataCompleteHouseholds = dfHouseholdDataByHousehold[iCompleteHouseholds]
dfHouseholdDataShortComplete = combine(dfHouseholdDataCompleteHouseholds,
    [:Date, :Hour, :DateAndHour, :Consumption])

dfHouseholdDataByHousehold = nothing
iCompleteHouseholds = nothing
dfHouseholdDataCompleteHouseholds = nothing
dfHouseholdDataShort = nothing
dfHouseholdDataShortComplete.Month = Dates.month.(dfHouseholdDataShortComplete.Date)
dfHouseholdDataShortComplete.DayOfWeek = Dates.dayofweek.(dfHouseholdDataShortComplete.Date)
dfHouseholdDataFinal = unstack(dfHouseholdDataShortComplete, :LCLid, :Consumption)
filter(row -> (row.LCLid .== "MAC004268" && row.Date .== Date("2013-06-29") && row.Hour .== 9), dfHouseholdDataShortComplete)
for column in eachcol(dfHouseholdDataFinal)
    Impute.impute!(column, Impute.Interpolate())
    Impute.impute!(column, Impute.LOCF())
    Impute.impute!(column, Impute.NOCB())
end
disallowmissing!(dfHouseholdDataFinal)

dfHouseholdDataByMonth = groupby(dfHouseholdDataFinal,
    [:Month, :DayOfWeek], sort = true)

c = @pipe groupby(dfHouseholdDataShortComplete, :LCLid) |>
    combine(_, [:Consumption => mean
                :Consumption => var
                :Consumption => minimum
                :Consumption => maximum])
Random.seed!(72945)
SelectedDays = (rand(1:12, 3), rand(1:7, 3))
dfHouseholdDataByMonth[(SelectedDays[1][1], SelectedDays[2][1])]
p = sort(repeat([i for i in 2:7], 3))
t = [repeat(SelectedDays, 7) ]

dfHouseholdDataByMonth[(SelectedDays[1,1], SelectedDays[1,2])]

b = Iterators.product(SelectedDays, a) |> collect
a = [2 3 4 5 6 7]'


TestSillhouettesOutput = Dict{}()

for testNumber in 1:3, NumberOfTestClusters in 2:7
    println("Month ", (SelectedDays[1][testNumber], " , day ", SelectedDays[2][testNumber]), ", number of clusters $NumberOfTestClusters" )
    CurrentPeriod = dfHouseholdDataByMonth[(SelectedDays[1][testNumber], SelectedDays[2][testNumber])]
    TestClusters = Clustering.kmeans(
        Matrix(CurrentPeriod[:,6:size(CurrentPeriod)[2]]), NumberOfTestClusters)
    TestSillhouettes = Clustering.silhouettes(TestClusters.assignments, TestClusters.counts,
            pairwise(SqEuclidean(), Matrix(CurrentPeriod[:,6:size(CurrentPeriod)[2]])))
    SilhouetteScore = mean(TestSillhouettes)
    push!(TestSillhouettesOutput, (SelectedDays[1][testNumber], SelectedDays[2][testNumber], NumberOfTestClusters) =>
        SilhouetteScore)
end

#a = @df JanMon StatsPlots.plot(:Hour, cols(2:3300), color = RGB(192/255,0,0),
#    legend = :none, linealpha = 0.05, ylim = (0,2),
#    title = "Short data, average daily profile")

a = dfHouseholdDataByMonth[(SelectedDays[1][1], SelectedDays[2][1])]
testProfiles = Clustering.kmeans(Matrix(a[:,6:size(a)[2]]), 5)
# pairwise(SqEuclidean(), Matrix(JanMon[:,6:size(JanMon)[2]]))
b = Clustering.silhouettes(testProfiles.assignments, testProfiles.counts,
    pairwise(SqEuclidean(), Matrix(a[:,6:size(a)[2]])))
mean(b)
testProfilesValues = testProfiles.centers
StatsPlots.plot!(test2.Hour, testProfilesValues, color = RGB(100/255, 100/255, 100/255),
    legend = :none, linealpha = 0.6, lw = 5)
