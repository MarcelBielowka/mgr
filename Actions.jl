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

function Output(Microgrid::Microgrid, dCurrentStep::DateTime, Action::Float64)
    dfCurrentProduction = filter(row-> row.date==dCurrentStep,
        Microgrid.dfTotalProduction)
    dfCurrentConsumption = filter(row-> row.date==dCurrentStep,
        Microgrid.dfTotalProduction)
    iCurrentMismatch = dfCurrentProduction.TotalProduction - dfCurrentConsumption.TotalConsumption
    if (Action > 1 && Microgrid.EnergyStorage.iCurrentCharge < Microgrid.EnergyStorage.iMaxCapacity)
        iMaxPossibleCharge = min(Microgrid.EnergyStorage.iChargeRate,
            Microgrid.EnergyStorage.iMaxCapacity - Microgrid.EnergyStorage.iCurrentCharge)
        iCharge = min(iMaxPossibleCharge, (Action-1) * Microgrid.dfTotalConsumption)
        Microgrid.EnergyStorage.iCurrentCharge += iCharge

    else if (Action < 1 && Microgrid.EnergyStorage.iCurrentCharge > 0)
        iMaxPossibleDischarge = min(Microgrid.EnergyStorage.iDischargeRate,
            Microgrid.EnergyStorage.iMaxCapacity)
        iDischarge =

    end

end
