using CSV, DataFrames, Dates, Pipe, Statistics
using Clustering, StatsPlots, Random
using FreqTables, Impute, Distances
cd("C:/Users/Marcel/Desktop/mgr/kody")
cMasterDir = "C:/Users/Marcel/Desktop/mgr/data/LdnHouseDataSplit"

include("Households.jl")

myData = ReadRawData(cMasterDir)
myDataShort = filter(row -> (row.Date > Dates.Date("2012-12-31") && row.Date < Dates.Date("2014-01-01")),
    myData)

myDataComplete = ClearAndModifyHouseholdData(myDataShort)

myDataCompleteEnd = PrepareDataForClustering(myDataComplete)
myDataComplete = nothing
testData = myDataCompleteEnd[1]

CurrentPeriod = unstack(testData, :IDAndDay, :Consumption)
for column in eachcol(CurrentPeriod)
    Impute.impute!(column, Impute.Interpolate())
    Impute.impute!(column, Impute.LOCF())
    Impute.impute!(column, Impute.NOCB())
end
disallowmissing!(CurrentPeriod)
