using CSV, DataFrames, Dates, Pipe, Statistics

cd("C:/Users/Marcel/Desktop/mgr/kody")
cMasterDir = "C:/Users/Marcel/Desktop/mgr/data/LdnHouseDataSplit/LdnDataSplit"
AllHouseholdData = readdir(cMasterDir)


for FileNum in 1:length(AllHouseholdData)
    temp = CSV.File(string(cMasterDir,"/",AllHouseholdData[i])) |>
        DataFrame

end

temp = CSV.File(string(cMasterDir,"/",AllHouseholdData[2])) |>
    DataFrame
rename!(temp, [:LCLid, :stdorToU, :DateTime, :Consumption, :Acorn, :Acorn_grouped])
a = filter(row -> (row.stdorToU == "Std" && row.Consumption != "Null"),
                    temp)
a.DateTime = SubString.(a.DateTime,1,16)
a.DateTime = Dates.DateTime.(a.DateTime,
            DateFormat("y-m-d H:M"))
a.Consumption = parse.(Float64, a.Consumption)

a.Date = Dates.Date.(a.DateTime)
a.Hour = Dates.hour.(a.DateTime)

a_hourly = @pipe groupby(a, [:LCLid, :Date, :Hour]) |>
    combine(_, [:Consumption => mean => :Consumption])
