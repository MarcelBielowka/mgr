using Pipe, DataStructures

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

# Decision Map calculates the energy use on the move between the columns
# and up along the shelves
# move along rows is irrelevant - the consignment will need to move along them
# anyway
function GetDecisionMap(Map, DistanceMap,
        HandlingRoadString,
        ConveyorSectionLength, ConveyorSectionWidth,
        ConsignmentWeight, EffectivePull, Efficiency)
    DecisionMap = Array{Union{Float64, String, Nothing}}(nothing, size(Map))

    for i in 1:size(Map)[1], j in 1:size(Map)[2], k in 1:size(Map)[3]
        if isnothing(Map[i,j,k])
            # E = W = F * s / η
            # * 0.00027778 - conversion from joules to Wh
            DecisionMap[i,j,k] = (
                EffectivePull * abs(DistanceMap[i,j,k][2]) * ConveyorSectionLength +
                ConsignmentWeight * 9.81 * (abs(DistanceMap[i,j,k][3])-1)) * 0.000277778 / Efficiency
        else
            DecisionMap[i,j,k] = HandlingRoadString
        end
    end

    return DecisionMap
end

# Storage class definition
mutable struct Storage
    ID::Int
    StorageMap::Array
    DistanceMap::Array
    HandlingRoadString::String
    ConveyorSectionLength::Float16
    ConveyorSectionWidth::Float16
    ConveyorUnitMass::Float64
    ConveyorEfficiency::Float16
    FrictionCoefficient::Float64
    DepartureOrder::Queue
end

# Storage constructor
function Storage(ID, SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString,
                 ConveyorSectionLength, ConveyorSectionWidth, HandlingRoadWidth,
                 FrictionCoefficient, ConveyorEfficiency, ConveyorMassPerM2)
    StorageMap = GetStorageMap(SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString)
    DistanceMap = GetDistanceMap(StorageMap)
    ConveyorUnitMass = ConveyorSectionWidth * ConveyorSectionLength * ConveyorMassPerM2 * 2
    Storage(
        ID,
        StorageMap,
        DistanceMap,
        HandlingRoadString,
        ConveyorSectionLength,
        ConveyorSectionWidth,
        ConveyorUnitMass,
        ConveyorEfficiency,
        FrictionCoefficient,
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
    WeightPerMetre::Float64
    EffectivePull::Float64
    DecisionMap::Array
    Location::Tuple
    EnergyConsumption::Dict
end

# Consignment constructor
function Consignment(InID, Storage, Length, Width, Height, Weight)
    WeightPerMetre = Weight / Length
    EffectivePull = Storage.FrictionCoefficient * 9.81 * (Weight + Storage.ConveyorUnitMass)
    Consignment(
        InID,
        Dict{}(),
        Length,
        Width,
        Height,
        Weight,
        WeightPerMetre,
        EffectivePull,
        GetDecisionMap(Storage.StorageMap, Storage.DistanceMap,
            Storage.HandlingRoadString, Storage.ConveyorSectionLength,
            Storage.ConveyorSectionWidth, Weight, EffectivePull, Storage.ConveyorEfficiency),
        (),
        Dict{}()
    )
end

# Calculating the energy use
# Get the optimal location and apply physical properties
# W = F * s for horizontal move, W = m * g * h for vertical move
# + 1 in move along rows in EnergyIn - to mark the consignment needs to enter the building
# + 2 in move along rows in EnergyOut - consignment needs to leave the racks region (+1) and leave the building (+1)
function CalculateEnergyUse!(Storage::Storage, Consignment::Consignment, location::CartesianIndex)
    NoOfRows = size(Storage.StorageMap)[1]
    EnergyUseIn = (
        Consignment.EffectivePull * abs(Storage.DistanceMap[location][1] + 1) * Storage.ConveyorSectionWidth +
            Consignment.EffectivePull * abs(Storage.DistanceMap[location][2]) * Storage.ConveyorSectionLength +
            Consignment.Weight * 9.81 * (abs(Storage.DistanceMap[location][3])-1)
        ) * 0.000277778 / Storage.ConveyorEfficiency
    EnergyUseOut = (
        Consignment.EffectivePull * (NoOfRows - abs(Storage.DistanceMap[location][1]) + 2) * Storage.ConveyorSectionWidth +
            Consignment.EffectivePull * abs(Storage.DistanceMap[location][2]) * Storage.ConveyorSectionLength +
            Consignment.Weight * 9.81 * (abs(Storage.DistanceMap[location][3])-1)
        ) * 0.000277778 / Storage.ConveyorEfficiency
    push!(Consignment.EnergyConsumption,"In" => EnergyUseIn)
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
function LocateSlot!(Consignment::Consignment, Storage::Storage)
    IDtoprint = (Consignment.DataIn["Day"], Consignment.DataIn["HourIn"], Consignment.DataIn["ID"])
    println("Looking for a place for Consignment ", IDtoprint)
    location =
        findfirst(x ->
            x == minimum(
                Consignment.DecisionMap[findall(isnothing.(Storage.StorageMap).==1)]
            ), Consignment.DecisionMap
        )
    Consignment.Location = Tuple(location)
    println(Tuple(location), " slot allocated")
    CalculateEnergyUse!(Storage, Consignment, location)
    Storage.StorageMap[location] = Consignment
    enqueue!(Storage.DepartureOrder, Consignment)
end

#TestStorage = Storage(1,45,93,7, "||", 1.4, 1, 1.4, 0.33, 0.8, 1.1)
#TestConsignment = Consignment(Dict("Day" => 1, "HourIn" => 1, "ID" => 1),
#    TestStorage, 1.2, 0.8, 1.2, 100)
#a = LocateSlot!(TestConsignment, TestStorage)
#TestStorage.StorageMap[1,46,:]
#TestStorage.DepartureOrder
