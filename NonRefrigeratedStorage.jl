using Pipe: @pipe
using DataStructures, Random, Distributions, StatsPlots, DataFrames

cd("C:/Users/Marcel/Desktop/mgr/kody")
include("NonRefrigeratedStorageUtils.jl")
Random.seed!(72945)

ArrivalsDict = zip(0:23,
    [0, 0, 0, 0, 0, 0, 97, 77, 87, 97, 97, 97, 107, 117, 117, 117, 107, 97, 97, 87, 87, 65, 2, 0]) |> collect |> Dict
DeparturesDict = deepcopy(ArrivalsDict)

DistNumConsIn = Distributions.Poisson(48)
DistNumConsOut = Distributions.Poisson(30)
DistWeightCon = Distributions.Normal(1300, 200)
DistInitFill = Distributions.Uniform(0.2, 0.5)
#x1 = 0:0.1:200
#StatsPlots.plot(x1, pdf.(DistNumCon, x1))
#x2 = 0.1:0.1:500
#StatsPlots.plot(x2, pdf.(DistWeightCon, x2))
#StatsPlots.plot(x2, cdf.(DistWeightCon, x2))

MyStorage = Storage(1,45,93,7, "||", 1.4, 1, 1.4, 0.33, 0.8, 1.1)
InitFill = MyStorage.MaxCapacity * rand(DistInitFill)
for ConsNum in 1:InitFill
    CurrentCons = Consignment(
        Dict("Day" => 0, "HourIn" => 0, "ID" => ConsNum),
        MyStorage, 1.2, 0.8, 1.2, min(rand(DistWeightCon), 1500)
    )
    LocateSlot!(CurrentCons, MyStorage; optimise = false)
end

MyStorage

dfOverallPowerCons = DataFrame(WarehouseID = Int[], Day = Int[], Hour = Int[], ConsIn = Float64[], ConsOut = Float64[])
ConsumptionIn = 0
ConsumptionOut = 0
NoConsIn = rand(DistNumConsIn)
NoConsOut = rand(DistNumConsOut)
AllConsOut = Array{}
for ConsNum in 1:NoConsIn
    CurrentCons = Consignment(
        Dict("Day" => 1, "HourIn" => 1, "ID" => ConsNum),
        MyStorage, 1.2, 0.8, 1.2, min(rand(DistWeightCon), 1500)
    )
    LocateSlot!(CurrentCons, MyStorage)
    ConsumptionIn += CurrentCons.EnergyConsumption["In"]
end

for ConsNum in 1:NoConsOut
    ExpediatedCons = ExpediateConsignment!(MyStorage, 1, 2)
    ConsumptionOut += ExpediatedCons.EnergyConsumption["Out"]
    AllConsOut = vcat(AllConsOut, ExpediatedCons)
end

#using JuliaInterpreter
#push!(JuliaInterpreter.compiled_modules, Base)
[println(AllConsOut[i].EnergyConsumption["Out"]) for i in 2:length(AllConsOut)]
ConsumptionIn
ConsumptionOut
ConsumptionIn + ConsumptionOut
