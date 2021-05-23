using Pipe: @pipe
using DataStructures, Random, Distributions, StatsPlots, DataFrames

cd("C:/Users/Marcel/Desktop/mgr/kody")
include("NonRefrigeratedStorageUtils.jl")

#ArrivalsDict = zip(0:23,
#    floor.(0.5.*[0, 0, 0, 0, 0, 0, 48, 28, 38, 48, 48, 48, 58, 68, 68, 68, 58, 48, 48, 38, 38, 16, 2, 0])) |> collect |> Dict
ArrivalsDict = zip(0:23,
    floor.([0, 0, 0, 0, 0, 0, 48, 28, 38, 48, 48, 48, 58, 68, 68, 68, 58, 48, 48, 38, 38, 16, 2, 0])) |> collect |> Dict
DeparturesDict = zip(0:23,
    floor.([0, 0, 0, 0, 0, 0, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 0, 0])) |> collect |> Dict

#DistNumConsIn = Distributions.Poisson(48)
#DistNumConsOut = Distributions.Poisson(30)
DistWeightCon = Distributions.Normal(1300, 200)
DistInitFill = Distributions.Uniform(0.2, 0.5)
#x1 = 0:0.1:200
#StatsPlots.plot(x1, pdf.(DistNumCon, x1))
#x2 = 0.1:0.1:500
#StatsPlots.plot(x2, pdf.(DistWeightCon, x2))
#StatsPlots.plot(x2, cdf.(DistWeightCon, x2))



Random.seed!(72945)
#@time a = SimOneRun(40, 45,93,7, 1.4, 1, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)
@time a = SimOneRun(1, 10, 45, 51, 7, 1.4, 1.4, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||", 20, 60, 150,
        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)

a["Storage"].ElectricityConsumption
a.DispatchedConsignments[1]

#@time a = SimOneRun(1, 20, 45, 93, 7, 1.4, 1, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)

#@time a = SimWrapper(100, 20, 45, 51, 7, 1.4, 1, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)
#@time a = SimWrapper(1000, 20, 45, 51, 7, 1.4, 1.4, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)
@time testOutput = SimWrapper(10, 10, 45, 51, 7, 1.4, 1.4, 0.8,
        1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||", 20, 60, 150,
        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)
#@time a = SimWrapper(30, 10, 45, 93, 7, 1.4, 1.4, 0.8,
#        1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||", 20, 60, 150,
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)

testOutput[1]["Storage"]
FinalDF = testOutput[1]["Storage"].ElectricityConsumption
for i in 2:length(testOutput)
    FinalDF = vcat(FinalDF, testOutput[i]["Storage"].ElectricityConsumption)
end

insertcols!(FinalDF, :ConsumptionTotal => FinalDF.ConsumptionIn .+ FinalDF.ConsumptionOut .+ FinalDF.ConsumptionLightning)
Chupcabara = @pipe groupby(FinalDF, [:Day, :Hour]) |>
    combine(_, :ConsumptionTotal => mean => :Consumption,
                :ConsumptionTotal => std => :ConsumptionSampleStd,
                nrow => :Counts)
insertcols!(Chupcabara, :ConsumptionAvgStd => Chupcabara.ConsumptionSampleStd./sqrt.(Chupcabara.Counts))



FinalDF = vcat([FinalDF, testOutput[i]["Storage"].ElectricityConsumption for i in 2:length(testOutput)])
first(FinalDF, 5)
length(testOutput)
#####
# tests
MyStorage = Storage(1,45,93,7, "||", 1.4, 1, 1.4, 0.33, 0.8, 1.1)
InitFill = MyStorage.MaxCapacity * rand(DistInitFill)
InitFill = MyStorage.MaxCapacity

MyStorage2 = Storage(1,45,51,7, "||", 1.4, 1, 1.4, 0.33, 0.8, 1.1)
MyStorage2.StorageMap[:, 42:48, 1]
MyStorage2.MaxCapacity

for ConsNum in 1:InitFill
    CurrentCons = Consignment(
        Dict("Day" => 0, "Hour" => 0, "ID" => ConsNum),
        MyStorage, 1.2, 0.8, 1.2, min(rand(DistWeightCon), 1500)
    )
    LocateSlot!(CurrentCons, MyStorage; optimise = false)
end


#using JuliaInterpreter
#push!(JuliaInterpreter.compiled_modules, Base)
MyStorage = CreateNewStorage(1, 20, 45, 51, 7, "||",
    1.4, 1, 1.4,
    0.33, 0.8, 1.1,
    1.2, 0.8, 1.2,
    DistWeightCon, DistInitFill)
sum(isnothing.(MyStorage.StorageMap))
any(isnothing.(MyStorage.StorageMap))
CurrentCons = Consignment(
    Dict("Day" => 1, "Hour" => 1, "ID" => 2),
    MyStorage, 1.2, 0.8, 1.2, 1500
)

MyStorage.ElectricityConsumption[(MyStorage.ElectricityConsumption.Hour .==5) .&
    (MyStorage.ElectricityConsumption.Day .==7), "ConsumptionIn"] .+=5
MyStorage.ElectricityConsumption[:,"ConsumptionIn"]

a = DataFrame(a = [], b = [])
push!(a, (1,2))
a = vcat(a, DataFrame(a = collect(0:23), b = repeat([1],24)))
