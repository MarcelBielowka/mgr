using Pipe

SlotsLength = 45
SlotsWidth = 93
SlotsHeight = 7
ConsignmentLength = 1.2
ConsignmentWidth = 0.8
ConsignmentHeight = 1.2
ConsignmentWeight = 100
ConveyorSectionLength = 1.4
ConveyorSectionWidth = 1
HandlingRoadWidth = 1.4
FrictionCoefficient = 0.33
Efficiency = 0.8
ConveyorsMassPerM2 = 1.1
HandlingRoadString = "||"

mutable struct Storage
    StorageMap::Array
end

mutable struct Consignment
    Repackage::Bool
    Location::Int
    WaitingTime::Int
end

StorageMap = Array{Union{Consignment, String, Nothing}}(nothing, SlotsLength, SlotsWidth, SlotsHeight)

function AssignCorridors(Map)
    FinalMap = deepcopy(Map)
    for i in 1:size(FinalMap,2)
        if i%3 == 2
            FinalMap[:,i,:] .= HandlingRoadString
        end
    end
    return FinalMap
end

function TotalLengthOfConveyors(Map;
    ConveyorSectionLength = ConveyorSectionLength, HandlingRoadString = HandlingRoadString)
    # length of conveyors = length of the handling roads between the shelves
    # and of the top / bottom belts
    NumberOfHandlingRoads = sum([Map[1,:,1] .== HandlingRoadString][1])
    LengthOfHandlingRoads = size(Map,1) * NumberOfHandlingRoads
    LengthOfStartAndEndBelt = size(Map,2) * ConveyorSectionLength * 2
    return LengthOfHandlingRoads + LengthOfStartAndEndBelt
end

StorageMap = AssignCorridors(StorageMap)
# total length of conveyors in the entire warehouse
ConveyorsTotalLength = TotalLengthOfConveyors(StorageMap)
# mass of the conveyor in the entire warehouse - length * width * mass per m^2
# chosen model - U0/U0
ConveyorsUnitMass = ConveyorSectionWidth * ConveyorSectionLength * ConveyorsMassPerM2 * 2
ConveyorsTotalMass = ConveyorsTotalLength * ConveyorSectionWidth * ConveyorsMassPerM2 * 2
ConsignmentWeightPerMetre = ConsignmentWeight / ConsignmentLength
# CarriedConsigmentsWeight = ConsignmentWeightPerMetre * ConveyorSectionLength
EffectivePull = FrictionCoefficient * 9.81 * (ConsignmentWeight + ConveyorsUnitMass)
# a = Tuple.(CartesianIndices(StorageMap) .- CartesianIndex(0,47,0))

StorageMap
StorageMapOriginal = deepcopy(StorageMap)

function GetDistanceMatrix(Map)
    Distances = Tuple.(CartesianIndices(Map) .- CartesianIndex(0,47,0))
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

DistanceMatrix = GetDistanceMatrix(StorageMap)

function GetEnergyUseMatrix(Map;
        HandlingRoadString = HandlingRoadString,
        DistanceMatrix = DistanceMatrix,
        ConveyorSectionLength = ConveyorSectionLength,
        ConveyorSectionWidth = ConveyorSectionWidth,
        ConsignmentWeight = ConsignmentWeight,
        Efficiency = Efficiency)
    EnergyMatrix = Array{Union{Float64, String, Nothing}}(nothing, size(Map))
    DecisionMatrix = Array{Union{Float64, String, Nothing}}(nothing, size(Map))

    for i in 1:size(Map)[1], j in 1:size(Map)[2], k in 1:size(Map)[3]
        if isnothing(Map[i,j,k])
            # E = W = F * s / η
            # * 0.00027778 - conversion from joules to Wh
            EnergyMatrix[i,j,k] = (EffectivePull * abs(DistanceMatrix[i,j,k][1]) * ConveyorSectionWidth +
                EffectivePull * abs(DistanceMatrix[i,j,k][2]) * ConveyorSectionLength +
                ConsignmentWeight * 9.81 * (abs(DistanceMatrix[i,j,k][3])-1)) * 0.000277778 / Efficiency
            DecisionMatrix[i,j,k] = (EffectivePull * abs(DistanceMatrix[i,j,k][2]) * ConveyorSectionLength +
                ConsignmentWeight * 9.81 * (abs(DistanceMatrix[i,j,k][3])-1)) * 0.000277778 / Efficiency
        else
            EnergyMatrix[i,j,k] = HandlingRoadString
            DecisionMatrix[i,j,k] = HandlingRoadString
        end
    end

    return Dict("DecisionMatrix" => DecisionMatrix, "EnergyUseMatrix" => EnergyMatrix)
end

# Get The Decision and Energy Use Matrices
DecisionAndEnergyMatrix = GetEnergyUseMatrix(StorageMap)
# how locating the consignments works
# find all the nothings in the storage map (nothings are empty slots),
# then take only those locations into consideration,
# then find the minimum energy use in the decision matrix,
# then find the first slot with this minimum energy use,
# all neatly wrapped using λ function and findfirst
ComingConsignmentLocation =
    findfirst(x ->
        x == minimum(DecisionAndEnergyMatrix["DecisionMatrix"][findall(isnothing.(StorageMap).==1)]), DecisionAndEnergyMatrix["DecisionMatrix"]
    )
