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
SelectedDays = (rand(1:12, 3), rand(1:7, 3))
dfHouseholdDataByMonth[(SelectedDays[1][1], SelectedDays[2][1])]

for testNumber in 1:3
    
end

#a = @df JanMon StatsPlots.plot(:Hour, cols(2:3300), color = RGB(192/255,0,0),
#    legend = :none, linealpha = 0.05, ylim = (0,2),
#    title = "Short data, average daily profile")

Random.seed!(72945)
testProfiles = Clustering.kmeans(Matrix(a[:,6:size(a)[2]]), 2)
# pairwise(SqEuclidean(), Matrix(JanMon[:,6:size(JanMon)[2]]))
b = Clustering.silhouettes(testProfiles.assignments, testProfiles.counts,
    pairwise(SqEuclidean(), Matrix(a[:,6:size(a)[2]])))
mean(b)
testProfilesValues = testProfiles.centers
StatsPlots.plot!(test2.Hour, testProfilesValues, color = RGB(100/255, 100/255, 100/255),
    legend = :none, linealpha = 0.6, lw = 5)


#test = @pipe groupby(dfHouseholdDataShort, [:LCLid, :Hour]) |>
#    combine(_, [:Consumption => mean => :Consumption])
#test2 = unstack(test, :LCLid, :Consumption)
#test3 = dropmissing(test2)
#a = @df test2 StatsPlots.plot(:Hour, cols(2:3300), color = RGB(192/255,0,0),
#    legend = :none, linealpha = 0.05, ylim = (0,2),
#    title = "Short data, average daily profile")

#Random.seed!(72945)
#testProfiles = Clustering.kmeans(Matrix(test3[:,2:size(test3)[2]]), 3)
#testProfilesValues = testProfiles.centers
#StatsPlots.plot!(test2.Hour, testProfilesValues, color = RGB(100/255, 100/255, 100/255),
#    legend = :none, linealpha = 0.6, lw = 5)

#Matrix(test2[:,2:size(test2)[2]])

#test3 = unstack(dfHouseholdData, :LCLid, :DateAndHour)

aaa = filter(row -> (row.Date == Dates.Date("2013-01-14") && row.LCLid == "MAC002754"),
    dfHouseholdDataShort)

unique(dfHouseholdDataShort)
