using DataFrames, Random

#########################################
#### Energy storage definition class ####
#########################################
mutable struct EnergyStorage
    iMaxCapacity::Float64
    iChargeRate::Float64
    iDischargeRate::Float64
    iNumberOfCells::Int
end

function GetEnergyStorage(iMaxCapacity::Float64, iChargeRate::Float64, iDischargeRate::Float64, iNumberOfCells::Int)
    EnergyStorage(iMaxCapacity, iChargeRate, iDischargeRate, iNumberOfCells)
end
testStorage = GetEnergyStorage(10.5, 15.0, 9.50, 10)

#########################################
######## DayAhead class definition ######
#########################################
mutable struct DayAheadPrices
    dfDayAheadPrices::DataFrame
end

function GetDayAheadPrices(dfDayAheadPrices::DataFrame)
    return DayAheadPrices(dfDayAheadPrices)
end

testDA = GetDayAheadPrices(dfPowerPriceData)

#########################################
####### Wind park class definition ######
#########################################
mutable struct WindPark
    dfWindParkProductionData::DataFrame
    iNumberOfTurbines::Int
end

function GetWindPark(dfWindProductionData::DataFrame, iNumberOfTurbines::Int)
    return WindPark(dfWindProductionData, iNumberOfTurbines)
end
testWindPark = GetWindPark(dfWindProduction, 5)

#########################################
####### Warehouse class definition ######
#########################################
mutable struct Warehouse
    dfEnergyConsumption::DataFrame
    dfSolarProduction::DataFrame
    iNumberOfPanels::Int
    EnergyStorage::EnergyStorage
end

function GetWarehouse(dfEnergyConsumption::DataFrame, dfSolarProduction::DataFrame,
    iNumberOfPanels::Int, iStorageMaxCapacity::Float64, iStorageChargeRate::Float64,
    iStorageDischargeRate::Float64, iNumberOfStorageCells::Int)
    return Warehouse(
        dfEnergyConsumption,
        dfSolarProduction,
        iNumberOfPanels,
        GetEnergyStorage(iStorageMaxCapacity,
                         iStorageChargeRate,
                         iStorageDischargeRate,
                         iNumberOfStorageCells)
    )
end

TestWarehouse = GetWarehouse(WarehouseDataAggregated["dfWarehouseEnergyConsumption"], dfSolarProduction,
    600, 11.7, 1.5*11.75, 0.5*11.7, 10)

#########################################
###### Households class definition ######
#########################################
mutable struct ⌂
    EnergyConsumption::Dict
    GroupCounts::Dict
    iNumberOfHouseholds::Int
    EnergyStorage::EnergyStorage
end


function Get_⌂(HouseholdData::Dict, iNumberOfHouseholds::Int,
    iStorageMaxCapacity::Float64, iStorageChargeRate::Float64,
    iStorageDischargeRate::Float64, iNumberOfStorageCells::Int)
    return ⌂(
        HouseholdsData["HouseholdProfiles"],
        HouseholdsData["ClusteringCounts"],
        iNumberOfHouseholds,
        GetEnergyStorage(iStorageMaxCapacity,
                         iStorageChargeRate,
                         iStorageDischargeRate,
                         iNumberOfStorageCells)
    )
end

My_⌂ = Get_⌂(HouseholdsData, 100, 11.7, 7.0, 5.0, 10)
