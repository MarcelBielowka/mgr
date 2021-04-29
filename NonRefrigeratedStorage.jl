using Pipe: @pipe
using DataStructures, Random, Distributions, StatsPlots, DataFrames

cd("C:/Users/Marcel/Desktop/mgr/kody")
include("NonRefrigeratedStorageUtils.jl")

#ArrivalsDict = zip(0:23,
#    floor.(0.5.*[0, 0, 0, 0, 0, 0, 48, 28, 38, 48, 48, 48, 58, 68, 68, 68, 58, 48, 48, 38, 38, 16, 2, 0])) |> collect |> Dict
ArrivalsDict = zip(0:23,
    floor.([0, 0, 0, 0, 0, 0, 48, 28, 38, 48, 48, 48, 58, 68, 68, 68, 58, 48, 48, 38, 38, 16, 2, 0])) |> collect |> Dict
DeparturesDict = deepcopy(ArrivalsDict)

#DistNumConsIn = Distributions.Poisson(48)
#DistNumConsOut = Distributions.Poisson(30)
DistWeightCon = Distributions.Normal(1300, 200)
DistInitFill = Distributions.Uniform(0.2, 0.5)
#x1 = 0:0.1:200
#StatsPlots.plot(x1, pdf.(DistNumCon, x1))
#x2 = 0.1:0.1:500
#StatsPlots.plot(x2, pdf.(DistWeightCon, x2))
#StatsPlots.plot(x2, cdf.(DistWeightCon, x2))

function SimOneRun(RunID, SimWindow,
    SlotsLength, SlotsWidth, SlotsHeight,
    ConveyorSectionLength, ConveyorSectionWidth, ConveyorEfficiency,
    StorageSlotHeight, ConveyorMassPerM2,
    ConsignmentLength, ConsignmentWidth, ConsignmentHeight,
    FrictionCoefficient,  HandlingRoadString,
    DistWeightCon, DistInitFill,
    ArrivalsDict, DeparturesDict)

    # Additional consigns to send - any demand that was not met the previous hour
    AdditionalConsignsToSend = 0

    # Initiate a new storage
    NewStorage = CreateNewStorage(RunID, SimWindow,
        SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString,
        ConveyorSectionLength, ConveyorSectionWidth, StorageSlotHeight,
        FrictionCoefficient, ConveyorEfficiency, ConveyorMassPerM2,
        ConsignmentLength, ConsignmentWidth, ConsignmentHeight,
        DistWeightCon, DistInitFill)
    println("New warehouse is created. Dimensions are: $SlotsLength x $SlotsWidth x $SlotsHeight and the maximum capacity is ", NewStorage.MaxCapacity)

    # Simulation - for each day and each hour
    for Day in 1:1:SimWindow
        println("Day $Day")
        for Hour in 0:1:23
            println("Hour $Hour")
            # Get the number of the incoming and departing consignments
            DistNumConsIn = Distributions.Poisson(ArrivalsDict[Hour])
            DistNumConsOut = Distributions.Poisson(DeparturesDict[Hour])
            NumConsIn = rand(DistNumConsIn)
            NumConsOut = rand(DistNumConsOut) + AdditionalConsignsToSend
            AdditionalConsignsToSend = 0
            println("There are $NumConsIn new consignments coming in and $NumConsOut going out")

            # Departure section
            if NumConsOut == 0
                # if there are no consignments to be sent, nothing happens
                println("No consignments are sent out")
            else
                # otherwise, we check if there are any consignments in the warehouse
                for ConsOutID in 1:NumConsOut
                    if any(isa.(NewStorage.StorageMap, Consignment))
                        # if there are, send them
                        println("Consignment $ConsOutID")
                        ExpediatedConsign = ExpediateConsignment!(NewStorage, Day, Hour)
                        NewStorage.ElectricityConsumption[(NewStorage.ElectricityConsumption.Day .==Day) .&
                            (NewStorage.ElectricityConsumption.Hour .==Hour), "ConsumptionOut"] .+= ExpediatedConsign.EnergyConsumption["Out"]
                    else
                        # if not, add the unmet demand to the next hour
                        println("There are no more consignments in the warehouse")
                        AdditionalConsignsToSend += 1
                    end
                end
            end

            # Arrival section
            # If there are some consignments which did not fit in the previous hour
            # check, if they can fit in now
            if length(NewStorage.WaitingQueue) > 0
                LoopEnd = min(length(NewStorage.WaitingQueue), sum(isnothing.(NewStorage.StorageMap)))
                println("$LoopEnd consignments are coming from the queue")
                for ConsWait in 1:LoopEnd
                    println(ConsWait)
                    ConsignFromQueue = dequeue!(NewStorage.WaitingQueue)
                    LocateSlot!(ConsignFromQueue, NewStorage)
                    NewStorage.ElectricityConsumption[(NewStorage.ElectricityConsumption.Day .==Day) .&
                        (NewStorage.ElectricityConsumption.Hour .==Hour), "ConsumptionIn"] .+= ConsignFromQueue.EnergyConsumption["In"]
                end
            end

            # New consignments
            if NumConsIn == 0
                # if there are no new consignments, nothing happens
                println("No consignments are admitted")
            else
                # OTherwise, create them and add to the warehouse
                for ConsInID in 1:NumConsIn
                    CurrentCons = Consignment(
                        Dict("Day" => Day, "Hour" => Hour, "ID" => ConsInID),
                        NewStorage, 1.2, 0.8, 1.2, min(rand(DistWeightCon), 1500)
                    )
                    LocateSlot!(CurrentCons, NewStorage)
                    NewStorage.ElectricityConsumption[(NewStorage.ElectricityConsumption.Day .==Day) .&
                        (NewStorage.ElectricityConsumption.Hour .==Hour), "ConsumptionIn"] .+= CurrentCons.EnergyConsumption["In"]
                end
            end
        end
        println("At EOD $Day ", sum(isnothing.(NewStorage.StorageMap)), " free slots remain")
    end

    # returning the outcome
    return NewStorage
end

function SimWrapper(NumberOfRuns, SimWindow,
    SlotsLength, SlotsWidth, SlotsHeight,
    ConveyorSectionLength, ConveyorSectionWidth, ConveyorEfficiency,
    StorageSlotHeight, ConveyorMassPerM2,
    ConsignmentLength, ConsignmentWidth, ConsignmentHeight,
    FrictionCoefficient,  HandlingRoadString,
    DistWeightCon, DistInitFill,
    ArrivalsDict, DeparturesDict)

    println("Starting the simluation")
    FinalDictionary = Dict()

    for Run in 1:NumberOfRuns
        println("Starting run number $Run")
        Output = SimOneRun(Run, SimWindow, SlotsLength, SlotsWidth, SlotsHeight,
            ConveyorSectionLength, ConveyorSectionWidth, ConveyorEfficiency,
            StorageSlotHeight, ConveyorMassPerM2,
            ConsignmentLength, ConsignmentWidth, ConsignmentHeight,
            FrictionCoefficient,  HandlingRoadString,
            DistWeightCon, DistInitFill,
            ArrivalsDict, DeparturesDict)
        push!(FinalDictionary, Run => Output)
        println("Simulation $Run is over, results are saved")
    end
    println("The entire simulation is finished, returning the results")
    return FinalDictionary
end

Random.seed!(72945)
#@time a = SimOneRun(40, 45,93,7, 1.4, 1, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)
@time a = SimOneRun(1, 10, 45, 51, 7, 1.4, 1, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)
a.ElectricityConsumption
a.DispatchedConsignments[1]

#@time a = SimOneRun(1, 20, 45, 93, 7, 1.4, 1, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)

#@time a = SimWrapper(100, 20, 45, 51, 7, 1.4, 1, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)
@time a = SimWrapper(10, 10, 45, 51, 7, 1.4, 1, 0.8, 1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)
#@time a = SimWrapper(100, 20, 45, 93, 7, 1.4, 1, 0.8,
#        1.4, 1.1, 1.2, 0.8, 1.2, 0.33, "||",
#        DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict)


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
