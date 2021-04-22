using Pipe, DataStructures

function AssignCorridors(Map, HandlingRoadString)
    FinalMap = deepcopy(Map)
    for i in 1:size(FinalMap,2)
        if i%3 == 2
            FinalMap[:,i,:] .= HandlingRoadString
        end
    end
    return FinalMap
end

function GetStorageMap(SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString)
    StorageMap = Array{Union{Consignment, String, Nothing}}(nothing, SlotsLength, SlotsWidth, SlotsHeight)
    StorageMap = AssignCorridors(StorageMap, HandlingRoadString)
    return StorageMap
end

function TotalLengthOfConveyors(Map, ConveyorSectionLength, HandlingRoadString)
    # length of conveyors = length of the handling roads between the shelves
    # and of the top / bottom belts
    NumberOfHandlingRoads = sum([Map[1,:,1] .== HandlingRoadString][1])
    LengthOfHandlingRoads = size(Map,1) * NumberOfHandlingRoads
    LengthOfStartAndEndBelt = size(Map,2) * ConveyorSectionLength * 2
    return LengthOfHandlingRoads + LengthOfStartAndEndBelt
end

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

function GetConsumptionMaps(Map, DistanceMap,
        HandlingRoadString,
        ConveyorSectionLength, ConveyorSectionWidth,
        ConsignmentWeight, EffectivePull, Efficiency)
    EnergyMap = Array{Union{Float64, String, Nothing}}(nothing, size(Map))
    DecisionMap = Array{Union{Float64, String, Nothing}}(nothing, size(Map))

    for i in 1:size(Map)[1], j in 1:size(Map)[2], k in 1:size(Map)[3]
        if isnothing(Map[i,j,k])
            # E = W = F * s / η
            # * 0.00027778 - conversion from joules to Wh
            EnergyMap[i,j,k] = (EffectivePull * abs(DistanceMap[i,j,k][1]) * ConveyorSectionWidth +
                EffectivePull * abs(DistanceMap[i,j,k][2]) * ConveyorSectionLength +
                ConsignmentWeight * 9.81 * (abs(DistanceMap[i,j,k][3])-1)) * 0.000277778 / Efficiency
            DecisionMap[i,j,k] = (EffectivePull * abs(DistanceMap[i,j,k][2]) * ConveyorSectionLength +
                ConsignmentWeight * 9.81 * (abs(DistanceMap[i,j,k][3])-1)) * 0.000277778 / Efficiency
        else
            EnergyMap[i,j,k] = HandlingRoadString
            DecisionMap[i,j,k] = HandlingRoadString
        end
    end

    return Dict("DecisionMap" => DecisionMap, "EnergyUseMap" => EnergyMap)
end

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

mutable struct Consignment
    ID::Dict
    Length::Float16
    Width::Float16
    Height::Float16
    Weight::Float64
    WeightPerMetre::Float64
    EffectivePull::Float64
    ConsumptionMaps::Dict
    Location::Tuple
    EnergyConsumption::Dict
end

function Consignment(ID, Storage, Length, Width, Height, Weight)
    WeightPerMetre = Weight / Length
    EffectivePull = Storage.FrictionCoefficient * 9.81 * (Weight + Storage.ConveyorUnitMass)
    Consignment(
        ID,
        Length,
        Width,
        Height,
        Weight,
        WeightPerMetre,
        EffectivePull,
        GetConsumptionMaps(Storage.StorageMap, Storage.DistanceMap,
            Storage.HandlingRoadString, Storage.ConveyorSectionLength,
            Storage.ConveyorSectionWidth, Weight, EffectivePull, Storage.ConveyorEfficiency),
        (),
        Dict{}()
    )
end

function LocateSlot(Consignment::Consignment, Storage::Storage)
    Location =
        findfirst(x ->
            x == minimum(Consignment.ConsumptionMaps["DecisionMap"][findall(isnothing.(Storage.StorageMap).==1)]), Consignment.ConsumptionMaps["DecisionMap"]
        )
    return Location
end

TestStorage.StorageMap[Tuple(a)]
TestStorage.StorageMap[1,3,2]

TestStorage = Storage(1,45,93,7, "||", 1.4, 1, 1.4, 0.33, 0.8, 1.1)
TestConsignment = Consignment(Dict("Day" => 1, "HourIn" => 1, "ID" => 1, "HourOut" => missing),
    TestStorage, 1.2, 0.8, 1.2, 100)
a = LocateSlot(TestConsignment, TestStorage)
