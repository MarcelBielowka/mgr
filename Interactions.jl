using Pipe

function SellEnergy(dDateHour::DateTime,
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

    iPowerSoldToHouseholds = iPercentage * iTotalProduction

    iSellProceeds = iPowerSoldToHouseholds * iMicrogridPrice +
        (iTotalProduction - iPowerSoldToHouseholds) * iGridPrice

    return Dict(
        "iPowerSoldToHouseholds" => iPowerSoldToHouseholds,
        "iPowerSoldToGrid" => iTotalProduction - iPowerSoldToHouseholds,
        "iSellProceeds" => iSellProceeds
    )
end

function SellEnergy(dDateHour::DateTime,
    Warehouse::Warehouse,
    iPercentage::Float64,
    iMicrogridPrice::Float64,
    DayAheadPrice::DayAheadPricesHandler)

    iGridPrice = filter(
        row -> (
            row.DeliveryDate == Dates.Date(dDateHour) && row.DeliveryHour == Dates.hour(dDateHour)
        ), DayAheadPrice.dfDayAheadPrices).Price[1]
    iTotalProduction = filter(
        row -> row.date == dDateHour, Warehouse.SolarPanels.dfSolarProductionData
    ).dfSolarProduction[1]

    iPowerSoldToHouseholds = iPercentage * iTotalProduction

    iSellProceeds = iPowerSoldToHouseholds * iMicrogridPrice +
        (iTotalProduction - iPowerSoldToHouseholds) * iGridPrice

    return Dict(
        "iPowerSoldToHouseholds" => iPowerSoldToHouseholds,
        "iPowerSoldToGrid" => iTotalProduction - iPowerSoldToHouseholds,
        "iSellProceeds" => iSellProceeds
    )
end

#Juno.@enter WindParkSellEnergy(Dates.DateTime("2019-11-04T07:00"), MyWindPark, 0.5, iMicrogridPrice, DayAheadPowerPrices)
SellEnergy(Dates.DateTime("2019-11-04T07:00"), MyWindPark, 0.7, iMicrogridPrice, DayAheadPowerPrices)
filter(row -> row.date == Dates.DateTime("2019-11-04T07:00"), MyWindPark.dfWindParkProductionData)
filter(row -> (
        row.DeliveryDate == Dates.Date("2019-11-04") && row.DeliveryHour== 07
    ), DayAheadPowerPrices.dfDayAheadPrices)

#abc = Dates.DateTime("2021-04-05T03:00:00")
#Dates.dayofweek(abc)
#Dates.month(abc)

SellEnergy(Dates.DateTime("2019-11-04T10:00"), MyWarehouse, 0.7, iMicrogridPrice, DayAheadPowerPrices)
filter(row -> row.date == Dates.DateTime("2019-11-04T10:00"), MyWarehouse.SolarPanels.dfSolarProductionData)
filter(row -> (
        row.DeliveryDate == Dates.Date("2019-11-04") && row.DeliveryHour== 10
    ), DayAheadPowerPrices.dfDayAheadPrices)
