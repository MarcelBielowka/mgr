using Pipe, DataFrames, Dates

function AggregateWarehouseConsumptionDataForMonth(iMonth::Int, iYear::Int,
    Warehouse::Warehouse)

    dFirstDayOfMonth = Dates.Date(string(iYear, "-", iMonth, "-01"))
    iDayOfWeekOfFDOM = Dates.dayofweek(dFirstDayOfMonth)
    iDaysInMonth = Dates.daysinmonth(dFirstDayOfMonth)

    dfWarehouseConsumptionMonthly = filter(
        row -> (row.Day >= iDayOfWeekOfFDOM && row.Day < iDayOfWeekOfFDOM + iDaysInMonth),
        MyWarehouse.dfEnergyConsumption
    )
    insertcols!(dfWarehouseConsumptionMonthly,
        :month => repeat([iMonth], nrow(dfWarehouseConsumptionMonthly)),
        :DayOfWeek => dfWarehouseConsumptionMonthly.Day .% 7)

    #filter!(row -> row.Day <= Dates.daysinmonth(dFirstDayOfMonth), dfUnorderedWarehouseData)
    return dfWarehouseConsumptionMonthly
end

dfWarehouseFinalConsumptionData = AggregateWarehouseConsumptionDataForMonth(1, 2019, MyWarehouse)

function AggregateWarehouseConsumptionData(iYear::Int, Warehouse::Warehouse)
    dfFinalConsumption = AggregateWarehouseConsumptionDataForMonth(1, iYear, Warehouse)
    for month in 2:12
        dfMonthlyData = AggregateWarehouseConsumptionDataForMonth(month, iYear, Warehouse)
        dfFinalConsumption = vcat(dfFinalConsumption, dfMonthlyData)
    end
    return dfFinalConsumption
end


dfWarehouseFinalConsumptionData = AggregateWarehouseConsumptionData(2019, MyWarehouse)






function AggregateHouseholdsConsumptionDataForMonth(iMonth::Int, iYear::Int,
    cAnalysisStartDate::String,
    dPLHolidayCalendar::Array, Households::⌂)

    dDates = repeat([Dates.Date(cAnalysisStartDate)], 24)
    for i in 1:364
        dDates = vcat(dDates, repeat([Dates.Date(cAnalysisStartDate) + Dates.Day(i)], 24))
    end
    dHours = @pipe collect(0:1:23) |> repeat(_, 365)
    dfHouseholdConsumption = DataFrame(
        date = Dates.DateTime.(string.(dDates, "T", dHours))
    )
    insertcols!(dfHouseholdConsumption,
        :month => Dates.month.(dfHouseholdConsumption.date),
        :DayOfWeek => Dates.dayofweek.(dfHouseholdConsumption.date),
        :Holiday => 0,
        :WeightedProfile => 0)
    return dfHouseholdConsumption
end

test = AggregateHouseholdsConsumptionDataForMonth(1,2019,"2019-01-01",
    dPLHolidayCalendar, Households)
filter



a = repeat([Dates.Date("2019-01-01")], 24)
b = @pipe collect(0:1:23) |> repeat(_, 365)
a
unique(a)
@pipe

Dates.DateTime.(string.(a, "T", b))

for i in 1:364
    a = vcat(a, repeat([Dates.Date("2019-01-01") + Dates.Day(i)], 24))
end

[repeat([Dates.Date("2019-01-01") + Dates.Day(i)], 24) for i in 0:364]

Dates.Day(1)
u = dayofweek(Dates.Date(string(b, "-", a + 1, "-01")))
u + daysinmonth(Dates.Date(string(b, "-", a + 1, "-01")))

abc = deepcopy(MyWarehouse.dfEnergyConsumption)
abc.Day = abc.Day .- (t-1)

FirstPart = filter(row -> row.Day >= t, MyWarehouse.dfEnergyConsumption)
SecondPart = filter(row -> row.Day < t, MyWarehouse.dfEnergyConsumption)
Reordered = vcat(FirstPart, SecondPart)

ReorderAgain = vcat(filter(row -> row.Day >= t, MyWarehouse.dfEnergyConsumption),
                    filter(row -> row.Day < t, MyWarehouse.dfEnergyConsumption))

test = AggregateWarehouseConsumptionDataForMonth(2, 2019, dPLHolidayCalendar, MyWarehouse)
