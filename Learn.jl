




function HouseholdsBuyEnergy(dDateHour::DateTime,
    Households::⌂,
    iPowerFromWF::Float64
    iPercentage::Float64,
    iMicrogridPrice::Float64,
    DayAheadPrice::DayAheadPricesHandler)

    dfHouseholdConsumptionDaily = Households.EnergyConsumption[
        Dates.month(dDateHour), Dates.dayofweek(dDateHour)
    ]

    dfHouseholdConsumptionHourly


end
