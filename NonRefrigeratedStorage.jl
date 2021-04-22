using Pipe, DataStructures, Random, Distributions
using StatsPlots

cd("C:/Users/Marcel/Desktop/mgr/kody")
include("NonRefrigeratedStorageUtils.jl")
Random.seed!(79245)

DistNumCon = Distributions.Poisson(41)
DistWeightCon = Distributions.Normal(200, 50)
#x1 = 0:0.1:200
#StatsPlots.plot(x1, pdf.(DistNumCon, x1))
#x2 = 0.1:0.1:500
#StatsPlots.plot(x2, pdf.(DistWeightCon, x2))
#StatsPlots.plot(x2, cdf.(DistWeightCon, x2))

MyStorage = Storage(1,45,93,7, "||", 1.4, 1, 1.4, 0.33, 0.8, 1.1)
at = rand(DistNumCon)
for ConsNum in 1:50
    CurrentCons = Consignment(Dict("Day" => 1, "HourIn" => 1, "ID" => ConsNum),
         MyStorage, 1.2, 0.8, 1.2, 100)
    LocateSlot!(CurrentCons, MyStorage)
end

#using JuliaInterpreter
#push!(JuliaInterpreter.compiled_modules, Base)

isa(MyStorage.StorageMap[1, 46, 2], Consignment)
MyStorage.DepartureOrder[1]
