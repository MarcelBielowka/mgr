function AggregateWarehouseConsumptionDataForMonth(Month::Int, Year::Int,
    dHolidaysCalendar::Array,
    Warehouse::Warehouse)

    dFirstDayOfMonth = Dates.Date(string(Year, "-", Month, "-01"))
    iDayOfWeekOfFDOM = Dates.dayofweek(dFirstDayOfMonth)
    iDaysInMonth = Dates.daysinmonth(dFirstDayOfMonth)

    dfWarehouseConsumptionMonthly = filter(
        row -> (row.Day >= iDayOfWeekOfFDOM && row.Day < iDayOfWeekOfFDOM + iDaysInMonth),
        MyWarehouse.dfEnergyConsumption
    )

    #filter!(row -> row.Day <= Dates.daysinmonth(dFirstDayOfMonth), dfUnorderedWarehouseData)
    return dfWarehouseConsumptionMonthly
end

a = 6
b = 2019
t = dayofweek(Dates.Date(string(b, "-", a, "-01")))
t + daysinmonth(Dates.Date(string(b, "-", a, "-01")))

test = filter(row -> (row.Day >= t && row.Day < t + daysinmonth(Dates.Date(string(b, "-", a, "-01"))))
    , MyWarehouse.dfEnergyConsumption)
test.DayOfWeek = test.Day .% 7

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
