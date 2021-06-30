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

    SellProceeds = iPercentage * iTotalProduction * iMicrogridPrice +
        (1 - iPercentage) * iTotalProduction * iGridPrice

    return SellProceeds
end

Juno.@enter WindParkSellEnergy(Dates.DateTime("2019-04-05T12:00"), MyWindPark, 0.5, iMicrogridPrice, DayAheadPowerPrices)
WindParkSellEnergy(Dates.DateTime("2019-04-05T12:00"), MyWindPark, 0.5, iMicrogridPrice, DayAheadPowerPrices)

abc = Dates.DateTime("2021-05-04T03:00")
hour(abc)
Date(abc)
