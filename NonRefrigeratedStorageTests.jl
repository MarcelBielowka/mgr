using Pipe: @pipe
using DataStructures, Random, Distributions, StatsPlots, DataFrames

#cd("C:/Users/Marcel/Desktop/mgr/kody")
#include("NonRefrigeratedStorageUtils.jl")

#ArrivalsDict = zip(0:23,
#    floor.(0.5.*[0, 0, 0, 0, 0, 0, 48, 28, 38, 48, 48, 48, 58, 68, 68, 68, 58, 48, 48, 38, 38, 16, 2, 0])) |> collect |> Dict
#ArrivalsDict = zip(0:23,
#    floor.([0, 0, 0, 0, 0, 0, 48, 28, 38, 48, 48, 48, 58, 68, 68, 68, 58, 48, 48, 38, 38, 16, 2, 0])) |> collect |> Dict
#DeparturesDict = zip(0:23,
#    floor.([0, 0, 0, 0, 0, 0, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 0, 0])) |> collect |> Dict

#DistNumConsIn = Distributions.Poisson(48)
#DistNumConsOut = Distributions.Poisson(30)
#DistWeightCon = Distributions.Normal(1300, 200)
#DistInitFill = Distributions.Uniform(0.2, 0.5)



#Random.seed!(72945)
#@time a = SimOneRun(40, 45,93,7, 1.4, 1, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)
#@time a = SimOneRun(1, 10, 45, 51, 7, 1.4, 1.4, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||", 20, 60, 150,
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)

#@time a = SimOneRun(1, 20, 45, 93, 7, 1.4, 1, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)

#@time a = SimWrapper(100, 20, 45, 51, 7, 1.4, 1, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)
#@time a = SimWrapper(1000, 20, 45, 51, 7, 1.4, 1.4, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)
#@time WarehouseOutputNonAggregated = SimWrapper(10, 10, 45, 51, 7, 1.4, 1.4, 0.8,
#        1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||", 20, 60, 150,
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)
#@time a = SimWrapper(30, 10, 45, 93, 7, 1.4, 1.4, 0.8,
#        1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||", 20, 60, 150,
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)

#WarehouseOutputAggregated = ExtractFinalStorageData(WarehouseOutputNonAggregated)
# WarehouseOutputAggregated["dfWarehouseEnergyConsumption"]
# WarehouseOutputAggregated["dfConsignmenstHistory"]
# WarehouseOutputAggregated["ExampleStorage"]
