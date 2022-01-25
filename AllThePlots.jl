### Power prices ###
# Power prices table
dfPowerPricesTable = describe(DayAheadPowerPrices.dfDayAheadPrices[!, [:Price]])
describe(DayAheadPowerPrices.dfDayAheadPrices.Price)
describe(Weather.dfWeatherData.Temperature)
describe(Weather.dfWeatherData.WindSpeed)
describe(Weather.dfWeatherData.Irradiation)
dfPowerPricesTable = describe(Weather.dfWeatherData[!, [:Temperature, :WindSpeed, :Irradiation]])

# Power prices graph
PlotPowerPrices = plot(Dates.DateTime.(Dates.year.(DayAheadPowerPrices.dfDayAheadPrices.DeliveryDate),
                                       Dates.month.(DayAheadPowerPrices.dfDayAheadPrices.DeliveryDate),
                                       Dates.day.(DayAheadPowerPrices.dfDayAheadPrices.DeliveryDate),
                                       DayAheadPowerPrices.dfDayAheadPrices.DeliveryHour),
                       DayAheadPowerPrices.dfDayAheadPrices.Price,
                       xlabel = "Delivery date",
                       ylabel = "Price [PLN/MWh]",
                       color = RGB(192/255, 0, 0),
                       legend = :none)
savefig(PlotPowerPrices, "C:/Users/Marcel/Desktop/mgr/graphs/PowerPrices.png")

dfCutOutPowerData = filter(row -> (week(row.DeliveryDate) >= 20 && week(row.DeliveryDate) <= 21),DayAheadPowerPrices.dfDayAheadPrices)
PlotWeekPowerPrices = plot(
                      Dates.DateTime.(Dates.year.(dfCutOutPowerData.DeliveryDate),
                                       Dates.month.(dfCutOutPowerData.DeliveryDate),
                                       Dates.day.(dfCutOutPowerData.DeliveryDate),
                                       dfCutOutPowerData.DeliveryHour),
                       dfCutOutPowerData.Price,
                       xlabel = "Delivery date",
                       ylabel = "Price [PLN/MWh]",
                       color = RGB(192/255, 0, 0),
                       legend = :none
                       )

PlotTemperature = StatsPlots.plot(
        Weather.dfWeatherData.date,
        Weather.dfWeatherData.Temperature,
        xlabel = "Delivery date",
        ylabel = "Temperature [C]",
        color = RGB(192/255, 0, 0),
        legend = :none,
        xlabelfontsize = 8,
        ylabelfontsize = 8,
        xtickfontsize = 6,
        ytickfontsize = 6
)
PlotIrradiation = StatsPlots.plot(
        Weather.dfWeatherData.date,
        Weather.dfWeatherData.Irradiation,
        xlabel = "Delivery date",
        ylabel = "Irradiation [W/m2]",
        color = RGB(192/255, 0, 0),
        legend = :none,
        xlabelfontsize = 8,
        ylabelfontsize = 8,
        xtickfontsize = 6,
        ytickfontsize = 6
)
PlotWindSpeed = StatsPlots.plot(
        Weather.dfWeatherData.date,
        Weather.dfWeatherData.WindSpeed,
        xlabel = "Delivery date",
        ylabel = "Wind speed [m/s]",
        color = RGB(192/255, 0, 0),
        legend = :none,
        xlabelfontsize = 8,
        ylabelfontsize = 8,
        xtickfontsize = 6,
        ytickfontsize = 6
)
PlotWeatherData = plot(PlotTemperature, PlotIrradiation, PlotWindSpeed, layout = (3,1))
savefig(PlotWeatherData, "C:/Users/Marcel/Desktop/mgr/graphs/PlotWeatherData.png")

PlotProduction = plot(
        MyWindPark.dfWindParkProductionData.date,
        MyWindPark.dfWindParkProductionData.WindProduction,
        label = "Wind production",
        color = RGB(100/255, 100/255, 100/255),
        alpha = 0.7,
        size = (800,600),
        legendfontsize = 8,
        xlabel = "Delivery date",
        ylabel = "Production [kWh]",
        xguidefontsize = 9,
        yguidefontsize = 9,
        leftmargin = 3Plots.mm,
        rightmargin = 3Plots.mm
)

plot!(
        MyWarehouse.SolarPanels.dfSolarProductionData.date,
        MyWarehouse.SolarPanels.dfSolarProductionData.dfSolarProduction,
        color = RGB(192/255, 0,0 ),
        alpha = 0.5,
        label = "Solar Production",
        legendfontsize = 8
)

savefig(PlotProduction, "C:/Users/Marcel/Desktop/mgr/graphs/PlotProduction.png")

### Households ###
HouseholdsJanSunPlots = RunPlots(Households.dictCompleteHouseholdsData, 1, 7)
HouseholdsJulSunPlots = RunPlots(Households.dictCompleteHouseholdsData, 7, 7; silhouettes = false)
HouseholdsJulMonPlots = RunPlots(Households.dictCompleteHouseholdsData, 7, 1; silhouettes = false)

savefig(HouseholdsJanSunPlots["PlotDataAndProfiles"],
        "C:/Users/Marcel/Desktop/mgr/graphs/ProfileJanSun.png")
savefig(HouseholdsJulSunPlots["PlotDataAndProfiles"],
        "C:/Users/Marcel/Desktop/mgr/graphs/ProfileJulSun.png")
savefig(HouseholdsJulMonPlots["PlotDataAndProfiles"],
        "C:/Users/Marcel/Desktop/mgr/graphs/ProfileJulMon.png")
savefig(HouseholdsJanSunPlots["PlotSillhouettes"],
        "C:/Users/Marcel/Desktop/mgr/graphs/HouseholdsSillhouettes.png")

### Warehouse ###
# Consignment stream
dfConsInData = DataFrame(:Hour => collect(keys(ArrivalsDict)), :ConsArriving => collect(values(ArrivalsDict)))
dfConsOutData = DataFrame(:Hour => collect(keys(DeparturesDict)), :ConsDeparting => collect(values(DeparturesDict)))
dfConsData = @pipe DataFrames.innerjoin(dfConsInData, dfConsOutData, on = :Hour) |>
        sort(_, order(:Hour)) |>
        stack(_, [:ConsArriving, :ConsDeparting], :Hour) |>
        rename!(_, [:Hour, :Status, :Number])
dfConsData.Status = String.(dfConsData.Status)

PlotExpectedConsignmentsStream = @df dfConsData StatsPlots.plot(:Hour, :Number, group = :Status,
        label = ["Consignments arriving" "Consignments departing"],
        legend = :topleft,
        lw = 2,
        color = [RGB(192/255, 0, 0) RGB(100/255, 100/255, 100/255)],
        padding = (0.0,0.0))
savefig(PlotExpectedConsignmentsStream,
        "C:/Users/Marcel/Desktop/mgr/graphs/ExpectedConsignmentsStream.png")

PlotWarehouseConsumption = plot(MyWarehouse.dfEnergyConsumption.Consumption[1:24*7],
        lw = 2,
        color = RGB(192/255,0,0),
        xlabel = "Hour of the week",
        ylabel = "Power consumption [kWh]",
        legend = :none)
savefig(PlotWarehouseConsumption,
        "C:/Users/Marcel/Desktop/mgr/graphs/WarehousePowerConsumption.png")
