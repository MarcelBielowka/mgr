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
    dfWindParkProductionData::DataFrame
end

function GetWindPark(WeatherData::WeatherDataHandler, iNumberOfTurbines::Int)
    dfWindProductionData = DataFrames.DataFrame(
        date = WeatherData.dfWeatherData.date,
        WindProduction = WindProductionForecast.(2000, WeatherData.dfWeatherData.WindSpeed, 11.5, 3, 20) .* iNumberOfTurbines
    )
    return WindPark(dfWindProductionData)
end
testWindPark = GetWindPark(TestWeather, 1)
testWindPark2 = GetWindPark(TestWeather, 5)

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

#TestWarehouse = GetWarehouse(WarehouseDataAggregated["dfWarehouseEnergyConsumption"], dfSolarProduction,
#    600, 11.7, 1.5*11.75, 0.5*11.7, 10)

#########################################
###### Households class definition ######
#########################################
mutable struct ⌂
    EnergyConsumption::Dict
    GroupCounts::Dict
    iNumberOfHouseholds::Int
    EnergyStorage::EnergyStorage
end


function Get_⌂(cHouseholdsDir::String, dHolidayCalendar,
    iNumberOfHouseholds::Int,
    iStorageMaxCapacity::Float64, iStorageChargeRate::Float64,
    iStorageDischargeRate::Float64, iNumberOfStorageCells::Int)
    dictHouseholdsData = GetHouseholdsData(cHouseholdsDir, dUKHolidayCalendar)
    return ⌂(
        dictHouseholdsData["HouseholdProfiles"],
        dictHouseholdsData["ClusteringCounts"],
        iNumberOfHouseholds,
        GetEnergyStorage(iStorageMaxCapacity,
                         iStorageChargeRate,
                         iStorageDischargeRate)
    )
end

#My_⌂ = Get_⌂(HouseholdsData, 100, 11.7, 7.0, 5.0, 10)
Test_⌂ = Get_⌂(cHouseholdsDir, dUKHolidayCalendar, 100, 11.7, 7.0, 5.0, 10)
