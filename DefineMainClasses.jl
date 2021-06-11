using DataFrames, Random

mutable struct EnergyStorage
    MaxCapacity::Float64
    Charge::Float64
    Discharge::Float64
end

function GetEnergyStorage(MaxCapacity::Float64, Charge::Float64, Discharge::Float64, NumberOfCells::Int)
    EnergyStorage(MaxCapacity*NumberOfCells, Charge*NumberOfCells, Discharge*NumberOfCells)
end
GetEnergyStorage(10.5, 15.0, 9.50, 10)



mutable struct WindPark
    WindProduction::DataFrame
end

function WindPark(dfWindProductionData)
    return WindPark(
        dfWindProductionData
    )
end

mutable struct Warehouse
    EnergyConsumption::DataFrame
    SolarProduction::DataFrame
    EnergyStorage::EnergyStorage
end

mutable struct ⌂
    EnergyConsumption::DataFrame
    EnergyStorage::EnergyStorage
end
