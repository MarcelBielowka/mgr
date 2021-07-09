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
    println("Constructor - creating the energy storage")
    EnergyStorage(iMaxCapacity * iNumberOfCells,
                  0,
                  iChargeRate * iNumberOfCells,
                  iDischargeRate * iNumberOfCells)
end
#testStorage = GetEnergyStorage(10.5, 15.0, 9.50, 10)

#########################################
### DayAhead handler class definition ###
#########################################
mutable struct DayAheadPricesHandler
    dfDayAheadPrices::DataFrame
    dfQuantilesOfPrices::DataFrame
end

function GetDayAheadPricesHandler(cPowerPricesDataDir::String,
    DeliveryFilterStart::String,
    DeliveryFilterEnd::String)
    println("Constructor - creating the DA prices handler")
    dfDayAheadPrices = ReadPrices(cPowerPricesDataDir,
        DeliveryFilterStart = DeliveryFilterStart,
        DeliveryFilterEnd = DeliveryFilterEnd)
    dfQuantilesOfPrices = @pipe dfDayAheadPrices |>
        groupby(_, :DeliveryHour) |>
        combine(_, :Price => (x -> quantile(x, 0.75)) => :iThirdQuartile,
                    :Price => (x -> quantile(x, 0.25)) => :iFirstQuartile)

    return DayAheadPricesHandler(dfDayAheadPrices, dfQuantilesOfPrices)
end

#testDA = GetDayAheadPricesHandler(cPowerPricesDataDir, cWeatherPricesDataWindowStart,
#    cWeatherPricesDataWindowEnd)


#########################################
### Weather handler class definition ####
#########################################
mutable struct WeatherDataHandler
    dfWeatherData::DataFrame
end

function GetWeatherDataHandler(cWindTempDataDir::String, cIrrDataDir::String,
    FilterStart::String,
    FilterEnd::String)

    println("Constructor - creating the weather data handler")
    dictWeatherDataDetails = ReadWeatherData(cWindTempDataDir, cIrrDataDir,
        FilterStart = FilterStart,
        FilterEnd = FilterEnd)
    return WeatherDataHandler(
        dictWeatherDataDetails["dfFinalWeatherData"]
    )
end

#TestWeather = GetWeatherDataHandler(cWindTempDataDir, cIrrDataDir,
#    cWeatherPricesDataWindowStart, cWeatherPricesDataWindowEnd)


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

    println("Constructor - creating the wind park. There will be $iNumberOfTurbines turbines")

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

#testWindPark = GetWindPark(2000.0, 11.5, 3.0, 20.0, TestWeather, 1)
#testWindPark2 = GetWindPark(2000.0, 11.5, 3.0, 20.0, TestWeather, 10)

#########################################
##### Solar panels class definition #####
#########################################
mutable struct SolarPanels
    iPVMaxCapacity::Float64
    iPVγ_temp::Float64
    iNoct::Int
    dfSolarProductionData::DataFrame
end

function GetSolarPanels(iPVMaxCapacity::Float64, iPVγ_temp::Float64,
    iNoct::Int, WeatherData::WeatherDataHandler, iNumberOfPanels::Int)

    dfSolarProductionData = DataFrames.DataFrame(
        date = WeatherData.dfWeatherData.date,
        dfSolarProduction = SolarProductionForecast.(iPVMaxCapacity, WeatherData.dfWeatherData.Irradiation,
            WeatherData.dfWeatherData.Temperature, iPVγ_temp, iNoct) .* iNumberOfPanels
    )
    return SolarPanels(
        iPVMaxCapacity, iPVγ_temp, iNoct, dfSolarProductionData
    )
end

# testPanel = GetSolarPanels(0.55, 0.0035, 45, Weather, 600)


#########################################
####### Warehouse class definition ######
#########################################
mutable struct Warehouse
    dfEnergyConsumption::DataFrame
    dfWarehouseEnergyConsumptionYearly::DataFrame
    dfConsignmentHistory::DataFrame
    SolarPanels::SolarPanels
    EnergyStorage::EnergyStorage
end

function GetWarehouse(
    iWarehouseNumberOfSimulations::Int, iWarehouseSimWindow::Int, iYear::Int,
    iPVMaxCapacity::Float64, iPVγ_temp::Float64,
    iNoct::Int, iNumberOfPanels::Int, WeatherData::WeatherDataHandler,
    iStorageMaxCapacity::Float64, iStorageChargeRate::Float64,
    iStorageDischargeRate::Float64, iNumberOfStorageCells::Int)

    println("Constructor - creating the warehouse")

    WarehouseSolarPanels = GetSolarPanels(
        iPVMaxCapacity, iPVγ_temp, iNoct, WeatherData, iNumberOfPanels
    )

    @time WarehouseDataRaw = pmap(SimWrapper,
        Base.Iterators.product(1:iWarehouseNumberOfSimulations, iWarehouseSimWindow, false))
    dictFinalData = ExtractFinalStorageData(WarehouseDataRaw, iYear)

    return Warehouse(
        dictFinalData["dfWarehouseEnergyConsumption"],
        dictFinalData["dfWarehouseEnergyConsumptionYearly"],
        dictFinalData["dfConsignmenstHistory"],
        WarehouseSolarPanels,
        GetEnergyStorage(iStorageMaxCapacity,
                         iStorageChargeRate,
                         iStorageDischargeRate,
                         iNumberOfStorageCells)
    )
end

#TestWarehouse = GetWarehouse(iWarehouseNumberOfSimulations, iWarehouseSimWindow,
#    0.55, 0.0035, 45, 600, Weather, 11.7, 1.5*11.75, 0.5*11.7, 10)

#########################################
####### Test warehouse constructor ######
#########################################
function GetTestWarehouse(
    dfWarehouseEnergyConsumption::DataFrame, dfConsignmentHistory::DataFrame,
    iYear::Int, iPVMaxCapacity::Float64, iPVγ_temp::Float64,
    iNoct::Int, iNumberOfPanels::Int, WeatherData::WeatherDataHandler,
    iStorageMaxCapacity::Float64, iStorageChargeRate::Float64,
    iStorageDischargeRate::Float64, iNumberOfStorageCells::Int)

    println("Constructor - creating the warehouse")

    WarehouseSolarPanels = GetSolarPanels(
        iPVMaxCapacity, iPVγ_temp, iNoct, WeatherData, iNumberOfPanels
    )

    dfWarehouseEnergyConsumptionYearly = AggregateWarehouseConsumptionData(dfWarehouseEnergyConsumption, iYear)

    return Warehouse(
        dfWarehouseEnergyConsumption,
        dfWarehouseEnergyConsumptionYearly,
        dfConsignmentHistory,
        WarehouseSolarPanels,
        GetEnergyStorage(iStorageMaxCapacity,
                         iStorageChargeRate,
                         iStorageDischargeRate,
                         iNumberOfStorageCells)
    )
end


#########################################
###### Households class definition ######
#########################################
mutable struct ⌂
    dfEnergyConsumption::DataFrame
    dictEnergyConsumption::Dict
    iNumberOfHouseholds::Int
    EnergyStorage::EnergyStorage
end

function Get_⌂(cHouseholdsDir::String,
    dOriginalHolidayCalendar::Array, dDestinationHolidayCalendar::Array,
    cStartDate::String, cEndDate::String,
    iNumberOfHouseholds::Int,
    iStorageMaxCapacity::Float64, iStorageChargeRate::Float64,
    iStorageDischargeRate::Float64, iNumberOfStorageCells::Int)

    println("Constructor - creating the households")

    dictHouseholdsData = GetHouseholdsData(cHouseholdsDir, dOriginalHolidayCalendar,
        dDestinationHolidayCalendar, cStartDate, cEndDate)
    dictProfileWeighted = dictHouseholdsData["HouseholdProfilesWeighted"]
    dfProfileWeighted = dictHouseholdsData["dfHouseholdProfilesWeighted"]
    dfProfileWeighted.ProfileWeighted .= dfProfileWeighted.ProfileWeighted .*100

    return ⌂(
        dfProfileWeighted,
        dictProfileWeighted,
        iNumberOfHouseholds,
        GetEnergyStorage(iStorageMaxCapacity,
                         iStorageChargeRate,
                         iStorageDischargeRate,
                         iNumberOfStorageCells)
    )
end

#Test_⌂ = Get_⌂(cHouseholdsDir, dUKHolidayCalendar, 100, 11.7, 7.0, 5.0, 10)

#########################################
###### Aggregator class definition ######
#########################################
mutable struct MicrogridAggregator
    PowerToSellWindPark::Float64
    PowerToSellWarehouse::Float64
end

function GetMicrogridAggregator()



end


#########################################
####### Microgrid class definition ######
#########################################
mutable struct Microgrid
    DayAheadPricesHandler::DayAheadPricesHandler
    WeatherDataHandler::WeatherDataHandler
    Constituents::Dict
    dfTotalProduction::DataFrame
    dfTotalConsumption::DataFrame
    EnergyStorage::EnergyStorage
end

function GetMicrogrid(DayAheadPricesHandler::DayAheadPricesHandler,
    WeatherDataHandler::WeatherDataHandler, MyWindPark::WindPark,
    MyWarehouse::Warehouse, MyHouseholds::⌂)

    dfTotalProduction = DataFrames.innerjoin(MyWindPark.dfWindParkProductionData,
        MyWarehouse.SolarPanels.dfSolarProductionData, on = :date)
    insertcols!(dfTotalProduction,
        :TotalProduction => dfTotalProduction.WindProduction .+ dfTotalProduction.dfSolarProduction)
    dfTotalConsumption = DataFrames.DataFrame(
        date = MyHouseholds.dfEnergyConsumption.date,
        HouseholdConsumption = MyHouseholds.dfEnergyConsumption.ProfileWeighted,
        WarehouseConsumption = MyWarehouse.dfWarehouseEnergyConsumptionYearly.Consumption
    )
    insertcols!(dfTotalConsumption,
        :TotalConsumption => dfTotalConsumption.HouseholdConsumption .+ dfTotalConsumption.WarehouseConsumption)

    return Microgrid(
        DayAheadPricesHandler, WeatherDataHandler,
        Dict(
            "Windpark" => MyWindPark,
            "Warehouse" => MyWarehouse,
            "Households" => MyHouseholds
        ),
        dfTotalProduction, dfTotalConsumption,
        GetEnergyStorage(MyHouseholds.EnergyStorage.iMaxCapacity + MyWarehouse.EnergyStorage.iMaxCapacity,
                         MyHouseholds.EnergyStorage.iChargeRate + MyWarehouse.EnergyStorage.iChargeRate,
                         MyHouseholds.EnergyStorage.iDischargeRate + MyWarehouse.EnergyStorage.iDischargeRate,
                         1)
    )

end
