using DataFrames, Random, Flux

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
#        groupby(_, :DeliveryHour) |>
        combine(_,
            [:Price => (x -> quantile(x, q)) => Symbol(string("i", Int(q*100)), "Centile") for q in 0.1:0.1:0.9]
        )

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
    iWarehouseNumberOfSimulations::Int, iWarehouseSimWindow::Int,
    iNumberOfWarehouses::Int, iYear::Int,
    iHeatCoefficient::Float64, iInsideTemp::Float64,
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
    dictFinalData = ExtractFinalStorageData(WarehouseDataRaw, iNumberOfWarehouses, iYear,
        WeatherData, iHeatCoefficient, iInsideTemp)

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
    iNumberOfWarehouses::Int, iYear::Int,
    iHeatCoefficient::Float64, iInsideTemp::Float64,
    iPVMaxCapacity::Float64, iPVγ_temp::Float64,
    iNoct::Int, iNumberOfPanels::Int, WeatherData::WeatherDataHandler,
    iStorageMaxCapacity::Float64, iStorageChargeRate::Float64,
    iStorageDischargeRate::Float64, iNumberOfStorageCells::Int)

    println("Constructor - creating the warehouse")

    WarehouseSolarPanels = GetSolarPanels(
        iPVMaxCapacity, iPVγ_temp, iNoct, WeatherData, iNumberOfPanels
    )

    dfWarehouseEnergyConsumptionYearly = AggregateWarehouseConsumptionData(
        dfWarehouseEnergyConsumption, iNumberOfWarehouses, iYear,
        WeatherData, iHeatCoefficient, iInsideTemp)

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
    dictHouseholdsData::Dict
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
    # dictProfileWeighted = dictHouseholdsData["HouseholdProfilesWeighted"]
    dfProfileWeighted = dictHouseholdsData["dfHouseholdProfilesWeighted"]
    dfProfileWeighted.ProfileWeighted .= dfProfileWeighted.ProfileWeighted .* iNumberOfHouseholds

    return ⌂(
        dfProfileWeighted,
        dictHouseholdsData,
        iNumberOfHouseholds,
        GetEnergyStorage(iStorageMaxCapacity,
                         iStorageChargeRate,
                         iStorageDischargeRate,
                         iNumberOfStorageCells)
    )
end

#Test_⌂ = Get_⌂(cHouseholdsDir, dUKHolidayCalendar, 100, 11.7, 7.0, 5.0, 10)

#########################################
######## Brain class definition #########
#########################################
mutable struct Brain
    β::Float64
    batch_size::Int
    memory_size::Int
    min_memory_size::Int
    memory::Array{Tuple,1}
    policy_net::Chain
    value_net::Chain
    ηₚ::Float64
    ηᵥ::Float64
    cPolicyOutputLayerType::String
end

function GetBrain(cPolicyOutputLayerType, iDimState; β = 0.999, ηₚ = 0.0001, ηᵥ = 0.0001)
    @assert any(["identity", "sigmoid"] .== cPolicyOutputLayerType) "The policy output layer type is not correct"

    if cPolicyOutputLayerType == "sigmoid"
        #policy_net = Chain(Dense(iDimState, 200, relu),
        #             Dense(200,200,relu),
        #             Dense(200,200,relu),
        #             Dense(200,2,sigmoid))
        #policy_net = Chain(
        #    Dense(iDimState, 1, sigmoid; bias = false)
        #)
        policy_net = nothing
    else
        policy_net = Chain(Dense(iDimState, 200, relu),
                     Dense(200,200,relu),
                     Dense(200,200,relu),
                    Dense(200,1, identity))
        #policy_net = Chain(
        #    Dense(iDimState, 1, identity)
        #)
    end
    #policy_net = Chain(
    #    Dense((iLookAhead + 1), 1, identity)
    #)
    #value_net = Chain(
    #    Dense(iDimState, 1, identity; bias = false)
    #)
    value_net = Chain(Dense(iDimState, 128, relu),
                #Dense(128, 128, relu),
                    Dense(128, 52, relu),
                    Dense(52, 1, identity))
    return Brain(β, 64, 1_200_000, 2_000, [], policy_net, value_net, ηₚ, ηᵥ, cPolicyOutputLayerType)
end

#########################################
####### Microgrid class definition ######
#########################################
mutable struct Microgrid
    Brain::Brain
    State::Vector
    Reward::Float64
    RewardHistory::Array
    DayAheadPricesHandler::DayAheadPricesHandler
    WeatherDataHandler::WeatherDataHandler
    Constituents::Dict
    dfTotalProduction::DataFrame
    dfTotalConsumption::DataFrame
    EnergyStorage::EnergyStorage
end

function GetMicrogrid(DayAheadPricesHandler::DayAheadPricesHandler,
    WeatherDataHandler::WeatherDataHandler, MyWindPark::WindPark,
    MyWarehouse::Warehouse, MyHouseholds::⌂, cPolicyOutputLayerType::String, iLookBack::Int)

    Brain = GetBrain(cPolicyOutputLayerType, 11)

    dfTotalProduction = DataFrames.innerjoin(MyWindPark.dfWindParkProductionData,
        MyWarehouse.SolarPanels.dfSolarProductionData, on = :date)
    insertcols!(dfTotalProduction,
        :TotalProduction => dfTotalProduction.WindProduction .+ dfTotalProduction.dfSolarProduction)
    # dfTotalProduction = dfTotalProduction[1:8759,:]
    dfTotalConsumption = DataFrames.DataFrame(
        date = MyHouseholds.dfEnergyConsumption.date,
        HouseholdConsumption = MyHouseholds.dfEnergyConsumption.ProfileWeighted,
        WarehouseConsumption = MyWarehouse.dfWarehouseEnergyConsumptionYearly.Consumption
    )
    insertcols!(dfTotalConsumption,
        :TotalConsumption => dfTotalConsumption.HouseholdConsumption .+ dfTotalConsumption.WarehouseConsumption)
    dfTotalConsumption = dfTotalConsumption[2:8760,:]
    dfTotalConsumption.date = dfTotalProduction.date

    return Microgrid(
        Brain,
        repeat([-Inf], 11),
        0.0,
        [],
        DayAheadPricesHandler,
        WeatherDataHandler,
        Dict(
            "Windpark" => MyWindPark,
            "Warehouse" => MyWarehouse,
            "Households" => MyHouseholds
        ),
        dfTotalProduction,
        dfTotalConsumption,
        GetEnergyStorage(MyHouseholds.EnergyStorage.iMaxCapacity + MyWarehouse.EnergyStorage.iMaxCapacity,
                         MyHouseholds.EnergyStorage.iChargeRate + MyWarehouse.EnergyStorage.iChargeRate,
                         MyHouseholds.EnergyStorage.iDischargeRate + MyWarehouse.EnergyStorage.iDischargeRate,
                         1)
    )

end
