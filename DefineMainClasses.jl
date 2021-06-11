using DataFrames

mutable struct EnergyStorage
    MaxCapacity::Float64
    Charge::Float64
    Discharge::Float64
end

mutable struct WindPark
    WindProduction::DataFrame
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
