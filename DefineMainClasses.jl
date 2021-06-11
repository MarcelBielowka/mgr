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
    EnergyStorage(iMaxCapacity*iNumberOfCells, iChargeRate*iNumberOfCells, iDischargeRate*iNumberOfCells, iNumberOfCells)
end
testStorage = GetEnergyStorage(10.5, 15.0, 9.50, 10)

#########################################
####### Wind park class definition ######
#########################################
mutable struct WindPark
    dfWindParkProductionData::DataFrame
    iNumberOfTurbines::Int
end

function GetWindPark(dfWindProductionData, iNumberOfTurbines)
    dfWindParkProductionData = deepcopy(dfWindProductionData)
    dfWindParkProductionData.WindProduction .*= iNumberOfTurbines
    return WindPark(dfWindParkProductionData,
        iNumberOfTurbines
    )
end
testWindPark = GetWindPark(dfWindProduction, 5)

mutable struct Warehouse
    EnergyConsumption::DataFrame
    SolarProduction::DataFrame
    EnergyStorage::EnergyStorage
end

mutable struct ⌂
    EnergyConsumption::DataFrame
    EnergyStorage::EnergyStorage
end
