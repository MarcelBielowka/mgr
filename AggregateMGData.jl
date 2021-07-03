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

function AggregateWarehouseConsumptionData(iYear::Int, Warehouse::Warehouse)
    dfFinalConsumption = AggregateWarehouseConsumptionDataForMonth(1, iYear, Warehouse)
    for month in 2:12
        dfMonthlyData = AggregateWarehouseConsumptionDataForMonth(month, iYear, Warehouse)
        dfFinalConsumption = vcat(dfFinalConsumption, dfMonthlyData)
    end
    return dfFinalConsumption
end

dfWarehouseFinalConsumptionData = AggregateWarehouseConsumptionData(2019, MyWarehouse)


function AggregateHouseholdsConsumptionDataForMonth(cStartDate::String, cEndDate::String,
    dHolidayCalendar::Array, Households::⌂)
    dfAggregatedHouseholdConsumption = DataFrame()
    for day in collect(Date(cStartDate):Day(1):Date(cEndDate))
        if any(dHolidayCalendar .== day)
            DayOfWeek = 7
        else
            DayOfWeek = Dates.dayofweek(day)
        end
        println(day, ", day of week is ", DayOfWeek)
        Month = Dates.month(day)
        Profile = Households.EnergyConsumption[(Month, DayOfWeek)]
        dfConsDay = hcat(repeat([day],24), Profile)
        dfAggregatedHouseholdConsumption = vcat(dfAggregatedHouseholdConsumption, dfConsDay)
    end
    return dfAggregatedHouseholdConsumption
end

test = AggregateHouseholdsConsumptionDataForMonth("2019-01-01", "2019-12-31",
    dPLHolidayCalendar, Households)

Households.EnergyConsumption[(8,5)]
