using DataFrames, Random

#########################################
#### Energy storage definition class ####
#########################################
mutable struct EnergyStorage
    iMaxCapacity::Float64
    iCurrentCharge::Float64
    iChargeRate::Float64
    iDischargeRate::Float64
end

function GetEnergyStorage(iMaxCapacity::Float64, iChargeRate::Float64, iDischargeRate::Float64, iNumberOfCells::Int)
    EnergyStorage(iMaxCapacity * iNumberOfCells,
                  0,
                  iChargeRate * iNumberOfCells,
                  iDischargeRate * iNumberOfCells)
end
testStorage = GetEnergyStorage(10.5, 15.0, 9.50, 10)

#########################################
### DayAhead handler class definition ###
#########################################
mutable struct DayAheadPricesHandler
    dfDayAheadPrices::DataFrame
end

function GetDayAheadPricesHandler(cPowerPricesDataDir::String,
    DeliveryFilterStart::String,
    DeliveryFilterEnd::String)
    dfDayAheadPrices = ReadPrices(cPowerPricesDataDir,
        DeliveryFilterStart = DeliveryFilterStart,
        DeliveryFilterEnd = DeliveryFilterEnd)

    return DayAheadPricesHandler(dfDayAheadPrices)
end

testDA = GetDayAheadPricesHandler(cPowerPricesDataDir, cWeatherPricesDataWindowStart,
    cWeatherPricesDataWindowEnd)


#########################################
### Weather handler class definition ####
#########################################
mutable struct WeatherDataHandler
    dfWeatherData::DataFrame
end

function GetWeatherDataHandler(cWindTempDataDir::String, cIrrDataDir::String,
    FilterStart::String,
    FilterEnd::String)

    dictWeatherDataDetails = ReadWeatherData(cWindTempDataDir, cIrrDataDir,
        FilterStart = FilterStart,
        FilterEnd = FilterEnd)
    return WeatherDataHandler(
        dictWeatherDataDetails["dfFinalWeatherData"]
    )

end

TestWeather = GetWeatherDataHandler(cWindTempDataDir, cIrrDataDir,
    cWeatherPricesDataWindowStart, cWeatherPricesDataWindowEnd)


#########################################
####### Wind park class definition ######
#########################################
mutable struct WindPark
    iTurbineMaxCapacity::Float64
    iTurbineRatedSpeed::Float64
    iTurbineCutinSpeed::Float64
    iTurbineCutoffSpeed::Float64
    dfWindParkProductionData::DataFrame
end

function GetWindPark(iTurbineMaxCapacity::Float64, iTurbineRatedSpeed::Float64,
    iTurbineCutinSpeed::Float64, iTurbineCutoffSpeed::Float64,
    WeatherData::WeatherDataHandler, iNumberOfTurbines::Int)
    dfWindProductionData = DataFrames.DataFrame(
        date = WeatherData.dfWeatherData.date,
        WindProduction = WindProductionForecast.(
            iTurbineMaxCapacity, WeatherData.dfWeatherData.WindSpeed,
            iTurbineRatedSpeed, iTurbineCutinSpeed, iTurbineCutoffSpeed
        ) .* iNumberOfTurbines
    )
    return WindPark(iTurbineMaxCapacity, iTurbineRatedSpeed,
        iTurbineCutinSpeed, iTurbineCutoffSpeed,
        dfWindProductionData)
end
testWindPark = GetWindPark(2000.0, 11.5, 3.0, 20.0, TestWeather, 1)
testWindPark2 = GetWindPark(2000.0, 11.5, 3.0, 20.0, TestWeather, 10)

#########################################
####### Warehouse class definition ######
#########################################
mutable struct Warehouse
    dfEnergyConsumption::DataFrame
    dfSolarProductionData::DataFrame
    iNumberOfPanels::Int
    EnergyStorage::EnergyStorage
end

function GetWarehouse(
    iWarehouseNumberOfSimulations::Int, iWarehouseSimWindow::Int,
    iPVMaxCapacity::Float64, iPVγ_temp::Float64,
    iNoct::Int, iNumberOfPanels::Int, WeatherData::WeatherDataHandler,
    iStorageMaxCapacity::Float64, iStorageChargeRate::Float64,
    iStorageDischargeRate::Float64, iNumberOfStorageCells::Int)

    dfSolarProductionData = DataFrames.DataFrame(
        date = WeatherData.dfWeatherData.date,
        dfSolarProduction = SolarProductionForecast.(iPVMaxCapacity, WeatherData.dfWeatherData.Irradiation,
            WeatherData.dfWeatherData.Temperature, iPVγ_temp, iNoct) .* iNumberOfPanels
    )

    dfEnergyConsumption = DataFrame()



    return Warehouse(
        dfEnergyConsumption,
        dfSolarProductionData,
        iNumberOfPanels,
        GetEnergyStorage(iStorageMaxCapacity,
                         iStorageChargeRate,
                         iStorageDischargeRate,
                         iNumberOfStorageCells)
    )
end

TestWarehouse = GetWarehouse(iWarehouseNumberOfSimulations, iWarehouseSimWindow,
    0.55, 0.0035, 45, 600, TestWeather, 11.7, 1.5*11.75, 0.5*11.7, 10)

#########################################
###### Households class definition ######
#########################################
mutable struct ⌂
    EnergyConsumption::Dict
    iNumberOfHouseholds::Int
    EnergyStorage::EnergyStorage
end

function Get_⌂(cHouseholdsDir::String, dHolidayCalendar,
    iNumberOfHouseholds::Int,
    iStorageMaxCapacity::Float64, iStorageChargeRate::Float64,
    iStorageDischargeRate::Float64, iNumberOfStorageCells::Int)
    dictHouseholdsData = GetHouseholdsData(cHouseholdsDir, dUKHolidayCalendar)
    dictProfileWeighted = dictHouseholdsData["HouseholdProfilesWeighted"]
    [dictProfileWeighted[(i,j)].ProfileWeighted .*= 100 for i in 1:12, j in 1:7]
    return ⌂(
        dictProfileWeighted,
        iNumberOfHouseholds,
        GetEnergyStorage(iStorageMaxCapacity,
                         iStorageChargeRate,
                         iStorageDischargeRate,
                         iNumberOfStorageCells)
    )
end

#My_⌂ = Get_⌂(HouseholdsData, 100, 11.7, 7.0, 5.0, 10)
Test_⌂ = Get_⌂(cHouseholdsDir, dUKHolidayCalendar, 100, 11.7, 7.0, 5.0, 10)
