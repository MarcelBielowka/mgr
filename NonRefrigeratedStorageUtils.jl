using Pipe: @pipe
using DataStructures, Random, Distributions, StatsPlots, DataFrames

# Corridors are assigned each third column - surrounded by two stacks of racks
function AssignCorridors(Map, HandlingRoadString)
    FinalMap = deepcopy(Map)
    for i in 1:size(FinalMap,2)
        if i%3 == 2
            FinalMap[:,i,:] .= HandlingRoadString
        end
    end
    return FinalMap
end

# Initialise the Storage Map and assign corridors
function GetStorageMap(SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString)
    StorageMap = Array{Union{Consignment, String, Nothing}}(nothing, SlotsLength, SlotsWidth, SlotsHeight)
    StorageMap = AssignCorridors(StorageMap, HandlingRoadString)
    return StorageMap
end

# Get the total length of the conveyors in the warehouse
function TotalLengthOfConveyors(Map, ConveyorSectionLength, HandlingRoadString)
    # length of conveyors = length of the handling roads between the shelves
    # and of the top / bottom belts
    NumberOfHandlingRoads = sum([Map[1,:,1] .== HandlingRoadString][1])
    LengthOfHandlingRoads = size(Map,1) * NumberOfHandlingRoads
    LengthOfStartAndEndBelt = size(Map,2) * ConveyorSectionLength * 2
    return LengthOfHandlingRoads + LengthOfStartAndEndBelt
end

# Get the distance map in the warehouse - needed for energy use calc
# Distances need to be centred on the main axis of the warehouse
function GetDistanceMap(Map)
    MoveCoef = Int(ceil(size(Map)[2]/2))
    Distances = Tuple.(CartesianIndices(Map) .- CartesianIndex(0,MoveCoef,0))
    DistancesFinal = deepcopy(Distances)
    for j in 1:size(Distances)[2]
        if (j < size(Distances)[2] / 2 && j%3 == 0)
            DistancesFinal[:,j,:] = DistancesFinal[:,j-2,:]
        elseif (j > size(Distances)[2] / 2 && j%3 == 1)
            DistancesFinal[:,j,:] = DistancesFinal[:,j+2,:]
        end
    end
    return DistancesFinal
end

mutable struct Conveyor
    ConveyorSectionLength::Float16
    ConveyorSectionWidth::Float16
    ConveyorUnitMass::Float16
    ConveyorEfficiency::Float16
    StorageSlotHeight::Float16
end

function Conveyor(ConveyorSectionLength::Float16, ConveyorSectionWidth::Float16,
        ConveyorEfficiency::Float16, ConveyorMassPerM2::Float16,
        StorageSlotHeight::Float16)
    ConveyorUnitMass = ConveyorSectionWidth * ConveyorSectionLength * ConveyorMassPerM2 * 2
    Conveyor(
        ConveyorSectionLength,
        ConveyorSectionWidth,
        ConveyorUnitMass,
        ConveyorEfficiency,
        StorageSlotHeight
    )
end

# Storage class definition
mutable struct Storage
    ID::Int
    StorageMap::Array
    DistanceMap::Array
    HandlingRoadString::String
    MaxCapacity::Int16
    Conveyor::Conveyor
    FrictionCoefficient::Float64
    ElectricityConsumption::DataFrame
    DepartureOrder::Queue
    WaitingQueue::Queue
end

# Storage constructor
function Storage(ID, SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString,
                 ConveyorSectionLength, ConveyorSectionWidth, StorageSlotHeight,
                 FrictionCoefficient, ConveyorEfficiency, ConveyorMassPerM2)
    StorageMap = GetStorageMap(SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString)
    DistanceMap = GetDistanceMap(StorageMap)
    WarehouseMaxCapacity = sum(isnothing.(StorageMap))
    ConveyorUnitMass = ConveyorSectionWidth * ConveyorSectionLength * ConveyorMassPerM2 * 2
    ConveyorSection = Conveyor(
        ConveyorSectionLength, ConveyorSectionWidth, ConveyorUnitMass,
        ConveyorEfficiency, StorageSlotHeight
    )
    Storage(
        ID,
        StorageMap,
        DistanceMap,
        HandlingRoadString,
        WarehouseMaxCapacity,
        ConveyorSection,
        FrictionCoefficient,
        DataFrame(WarehouseID = Int[], Day = Int[], Hour = Int[], ConsIn = Float64[], ConsOut = Float64[]),
        Queue{Consignment}(),
        Queue{Consignment}()
    )
end

# Consignment class defintion
mutable struct Consignment
    DataIn::Dict
    DataOut::Dict
    Length::Float16
    Width::Float16
    Height::Float16
    Weight::Float64
    EffectivePull::Float64
    Location::Tuple
    EnergyConsumption::Dict
    EverWaited::Bool
end

# Consignment constructor
function Consignment(InID, Storage, Length, Width, Height, Weight)
    WeightPerMetre = Weight / Length
    EffectivePull = Storage.FrictionCoefficient * 9.81 * (Weight + Storage.Conveyor.ConveyorUnitMass)
    Consignment(
        InID,
        Dict{}(),
        Length,
        Width,
        Height,
        Weight,
        EffectivePull,
        (),
        Dict{}(),
        false
    )
end

# Decision Map calculates the energy use on the move between the columns
# and up along the shelves
# move along rows is irrelevant -
# the consignment will need to move along them anyway
function GetDecisionMap(Storage::Storage, CurrentConsignment::Consignment)
    DecisionMap = Array{Union{Float64, String, Nothing}}(nothing, size(Storage.StorageMap))

    for i in 1:size(Storage.StorageMap)[1], j in 1:size(Storage.StorageMap)[2], k in 1:size(Storage.StorageMap)[3]
        if isnothing(Storage.StorageMap[i,j,k])
            # E = W = F * s / η
            # * 0.00000027778 - conversion from joules to kWh
            DecisionMap[i,j,k] = (
                CurrentConsignment.EffectivePull * abs(Storage.DistanceMap[i,j,k][2]) * Storage.Conveyor.ConveyorSectionLength +
                CurrentConsignment.Weight * 9.81 * (abs(Storage.DistanceMap[i,j,k][3])-1) * Storage.Conveyor.StorageSlotHeight
            ) * 0.000000277778 / Storage.Conveyor.ConveyorEfficiency
        elseif isa(Storage.StorageMap[i,j,k], Consignment)
            DecisionMap[i,j,k] = "T"
        else
            DecisionMap[i,j,k] = Storage.HandlingRoadString
        end
    end

    return DecisionMap
end

# Calculating the energy use
# Get the optimal location and apply physical properties
# W = F * s for horizontal move, W = m * g * h for vertical move
# + 1 in move along rows in EnergyIn - to mark the consignment needs to enter the building
# + 2 in move along rows in EnergyOut - consignment needs to leave the racks region (+1) and leave the building (+1)
# Energy in is only calculated when we optimise the energy use
function CalculateEnergyUse!(Storage::Storage, Consignment::Consignment,
        location::CartesianIndex, optimise::Bool)
    NoOfRows = size(Storage.StorageMap)[1]
    if optimise
        EnergyUseIn = (
            Consignment.EffectivePull * abs(Storage.DistanceMap[location][1] + 1 + 6) * Storage.Conveyor.ConveyorSectionWidth +
                Consignment.EffectivePull * abs(Storage.DistanceMap[location][2]) * Storage.Conveyor.ConveyorSectionLength +
                Consignment.Weight * 9.81 * (abs(Storage.DistanceMap[location][3])-1) * Storage.Conveyor.StorageSlotHeight
            ) * 0.000000277778 / Storage.Conveyor.ConveyorEfficiency
        push!(Consignment.EnergyConsumption,"In" => EnergyUseIn)
    end
    EnergyUseOut = (
        Consignment.EffectivePull * (NoOfRows - abs(Storage.DistanceMap[location][1]) + 2 + 6) * Storage.Conveyor.ConveyorSectionWidth +
            Consignment.EffectivePull * abs(Storage.DistanceMap[location][2]) * Storage.Conveyor.ConveyorSectionLength +
            Consignment.Weight * 9.81 * (abs(Storage.DistanceMap[location][3])-1) * Storage.Conveyor.StorageSlotHeight
        ) * 0.000000277778 / Storage.Conveyor.ConveyorEfficiency
    push!(Consignment.EnergyConsumption,"Out" => EnergyUseOut)
end

# how finding the optimal location works
# find all the nothings in the storage map (nothings are empty slots),
# then take only those locations into consideration,
# then find the minimum energy use in the decision matrix,
# then find the first slot with this minimum energy use,
# all neatly wrapped using λ function and findfirst
# then calculate the energy use on the way inside the warehouse and outside of it
# and finally enqueue the consignment into the waiting line
function LocateSlot!(Consignment::Consignment, Storage::Storage; optimise = true)
    # logs
    IDtoprint = (Consignment.DataIn["Day"], Consignment.DataIn["HourIn"], Consignment.DataIn["ID"])
    if any(isnothing.(Storage.StorageMap))
        if optimise
            println("Looking for a place for Consignment $IDtoprint")
            DecisionMap = GetDecisionMap(Storage, Consignment)
            location = findfirst(
                isequal(
                    minimum(DecisionMap[isnothing.(Storage.StorageMap)])
                ), DecisionMap
            )
            println(Tuple(location), " slot allocated. The value of decision matrix is ", DecisionMap[location])
        else
            location = rand(findall(isnothing.(Storage.StorageMap)))
            println(Tuple(location), " slot allocated to Consign ", IDtoprint, ". Energy use is not being optimised")
        end
        # calculate energy consumption and locate the consignment
        Consignment.Location = Tuple(location)
        CalculateEnergyUse!(Storage, Consignment, location, optimise)
        Storage.StorageMap[location] = Consignment
        # FIFO attribution
        enqueue!(Storage.DepartureOrder, Consignment)
    else
        if Consignment.EverWaited
            println("Readding the already waiting cons into queue. Execution stopped")
            return nothing
        end
        println("There are no more free spaces, consignment $IDtoprint added to waiting line")
        Consignment.EverWaited = true
        enqueue!(Storage.WaitingQueue, Consignment)
    end
end

# Send the consignment away
function ExpediateConsignment!(Storage::Storage,
            Day::Int, Hour::Int)
    CurrentCons = dequeue!(Storage.DepartureOrder)
    println(CurrentCons.DataIn, " is leaving the warehouse")
    push!(CurrentCons.DataOut, "Day" => Day)
    push!(CurrentCons.DataOut, "Hour" => Hour)
    Storage.StorageMap[CartesianIndex(CurrentCons.Location)] = nothing
    return CurrentCons
end

# initiate a new storage
function CreateNewStorage(ID, SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString,
    ConveyorSectionLength, ConveyorSectionWidth, StorageSlotHeight,
    FrictionCoefficient, ConveyorEfficiency, ConveyorMassPerM2,
    ConsignmentLength, ConsignmentWidth, ConsignmentHeight,
    DistWeightCon, DistInitFill)

    NewStorage = Storage(ID, SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString,
        ConveyorSectionLength, ConveyorSectionWidth, StorageSlotHeight,
        FrictionCoefficient, ConveyorEfficiency, ConveyorMassPerM2)

    InitFill = NewStorage.MaxCapacity * rand(DistInitFill)

    for ConsNum in 1:InitFill
        CurrentCons = Consignment(
            Dict("Day" => 0, "HourIn" => 0, "ID" => ConsNum),
            NewStorage,
            ConsignmentLength, ConveyorSectionWidth, 1.2, min(rand(DistWeightCon), 1500)
        )
        LocateSlot!(CurrentCons, NewStorage; optimise = false)
    end

    return NewStorage

end
