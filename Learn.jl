using Pipe

function WindParkSellEnergy(dDateHour::DateTime,
    WindPark::WindPark,
    iPercentage::Float64,
    iMicrogridPrice::Float64,
    DayAheadPrice::DayAheadPricesHandler)

    iGridPrice = filter(
        row -> (
            row.DeliveryDate == Dates.Date(dDateHour) && row.DeliveryHour == Dates.hour(dDateHour)
        ), DayAheadPrice.dfDayAheadPrices).Price[1]
    iTotalProduction = filter(
        row -> row.date == dDateHour, WindPark.dfWindParkProductionData
    ).WindProduction[1]

    iPowerSoldToMicrogrid = iPercentage * iTotalProduction

    iSellProceeds = iPowerSoldToMicrogrid * iMicrogridPrice +
        (iTotalProduction - iPowerSoldToMicrogrid) * iGridPrice

    return Dict(
        "iPowerSoldToMicrogrid" => iPowerSoldToMicrogrid,
        "iPowerSoldToGrid" => iTotalProduction - iPowerSoldToMicrogrid,
        "iSellProceeds" => iSellProceeds
    )
end

#Juno.@enter WindParkSellEnergy(Dates.DateTime("2019-11-04T07:00"), MyWindPark, 0.5, iMicrogridPrice, DayAheadPowerPrices)
WindParkSellEnergy(Dates.DateTime("2019-3-12T04:00"), MyWindPark, 0.7, iMicrogridPrice, DayAheadPowerPrices)
filter(row -> row.date == Dates.DateTime("2019-3-12T04:00"), MyWindPark.dfWindParkProductionData)
filter(row -> (
        row.DeliveryDate == Dates.Date("2019-11-04") && row.DeliveryHour== 07
    ), DayAheadPowerPrices.dfDayAheadPrices)

#abc = Dates.DateTime("2021-04-05T03:00:00")
#Dates.dayofweek(abc)
#Dates.month(abc)

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
