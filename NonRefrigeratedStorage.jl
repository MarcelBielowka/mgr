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

function SimOneRun(SimWindow,
    SlotsLength, SlotsWidth, SlotsHeight,
    ConveyorSectionLength, ConveyorSectionWidth, ConveyorEfficiency,
    StorageSlotHeight, ConveyorMassPerM2,
    ConsignmentLength, ConsignmentWidth, ConsignmentHeight,
    FrictionCoefficient,  HandlingRoadString,
    DistWeightCon, DistInitFill,
    ArrivalsDict, DepartureDict)

    DispatchedConsigns = Consignment[]

    # Initiate a new storage
    NewStorage = CreateNewStorage(1, SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString,
        ConveyorSectionLength, ConveyorSectionWidth, StorageSlotHeight,
        FrictionCoefficient, ConveyorEfficiency, ConveyorMassPerM2,
        ConsignmentLength, ConsignmentWidth, ConsignmentHeight,
        DistWeightCon, DistInitFill)

    #return NewStorage

    for Day in 1:1:SimWindow
        println("Day $Day")
        for Hour in 0:1:23
            println("Hour $Hour")
            DistNumConsIn = Distributions.Poisson(ArrivalsDict[Hour])
            DistNumConsOut = Distributions.Poisson(DepartureDict[Hour])
            NumConsIn = rand(DistNumConsIn)
            NumConsOut = rand(DistNumConsOut)
            println("There are $NumConsIn consignments coming in and $NumConsOut going out")
            if NumConsOut == 0
                println("No consignments are sent out")
            else
                for ConsOutID in 1:NumConsOut
                    println("Consignment $ConsOutID")
                    ExpediatedConsign = ExpediateConsignment!(NewStorage, Day, Hour)
                    push!(DispatchedConsigns, ExpediatedConsign)
                end
            end

            if NumConsIn == 0
                println("No consignments are admitted")
            else
                for ConsInID in 1:NumConsOut
                    println("Consignment $ConsInID")
                    CurrentCons = Consignment(
                        Dict("Day" => 1, "HourIn" => 1, "ID" => ConsNum),
                        NewStorage, 1.2, 0.8, 1.2, min(rand(DistWeightCon), 1500)
                    )
                    LocateSlot!(CurrentCons, NewStorage)
                end
            end
        end
    end


end

abc = Sim(45,93,7, 1.4, 1, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
    DistNumConsIn, DistNumConsOut, DistWeightCon, DistInitFill)
abc
length(abc.DepartureOrder)



#####
# tests
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
AllConsOut = []
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
MyStorage = Storage(1,45,93,7, "||", 1.4, 1, 1.4, 0.33, 0.8, 1.1)
CurrentCons = Consignment(
    Dict("Day" => 1, "HourIn" => 1, "ID" => 2),
    MyStorage, 1.2, 0.8, 1.2, 1500
)

t = GetDecisionMap(MyStorage, CurrentCons)
t[1,46,1]
t[1,46,2]
t[1, 43, 1]

t = Consignment[]
push!(t,CurrentCons)
t

z = DataFrame(a = String[], b = Int[])
