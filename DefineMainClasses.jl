using DataFrames, Random

mutable struct EnergyStorage
    MaxCapacity::Float64
    Charge::Float64
    Discharge::Float64
end

function GetEnergyStorage(MaxCapacity::Float64, Charge::Float64, Discharge::Float64)
    EnergyStorage(MaxCapacity, Charge, Discharge)
end
Juno.@enter GetEnergyStorage(10.5, 15.0, 9.50)

function EnergyStorage2(MaxCapacity::Float64, Coeffs::Float64)
    Charge = MaxCapacity * Coeffs
    Discharge = MaxCapacity / Coeffs
    EnergyStorage(MaxCapacity, Charge, Discharge)
end

Juno.@enter EnergyStorage2(10.0, 1.3)

mutable struct Agent
    age::Int
    income::Float64
end

function Agent(age::Int)
    income = rand()+age*10
    Agent(age, income)
end

Agent(20)

EnergyStorage(10.0, 10.0, 10.0)

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
