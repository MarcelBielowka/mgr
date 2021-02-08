using CSV, DataFrames, Dates, Pipe, Statistics
using Clustering, StatsPlots, Random
using FreqTables

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
dfHouseholdDataShort.Month = Dates.month.(dfHouseholdDataShort.Date)
dfHouseholdDataShort.DayOfWeek = Dates.dayofweek.(dfHouseholdDataShort.Date)

FreqTableReadings = FreqTables.freqtable(dfHouseholdDataShort.LCLid, dfHouseholdDataShort.Date)
m = [count(col.==24) for col in eachcol(FreqTableReadings)]
any(dfHouseholdDataShort.Consumption .< 0)

dfHouseholdDataByMonth = groupby(dfHouseholdDataShort,
    [:Month, :DayOfWeek], sort = true)

# dfHouseholdDataByMonth[1]

JanMon = unstack(dfHouseholdDataByMonth[1], :LCLid, :Consumption)
a = @df JanMon StatsPlots.plot(:Hour, cols(2:3300), color = RGB(192/255,0,0),
    legend = :none, linealpha = 0.05, ylim = (0,2),
    title = "Short data, average daily profile")

Random.seed!(72945)
testProfiles = Clustering.kmeans(Matrix(JanMon[:,2:size(test3)[2]]), 3)
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
