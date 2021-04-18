using Pipe

SlotsLength = 45
SlotsWidth = 93
SlotsHeight = 7
ConsignmentLength = 1.4
ConsignmentWidth = 1
ConsignmentHeight = 1.4
ConsignmentWeight = 100
HandlingRoadWidth = 1
CrictionCoefficient = 0.5
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
    ConsignmentLength = ConsignmentLength, HandlingRoadString = HandlingRoadString)
    # length of conveyors = length of the handling roads between the shelves
    # and of the top / bottom belts
    NumberOfHandlingRoads = sum([Map[1,:,1] .== HandlingRoadString][1])
    LengthOfHandlingRoads = size(Map,1) * NumberOfHandlingRoads
    LengthOfStartAndEndBelt = size(Map,2) * ConsignmentLength * 2
    return LengthOfHandlingRoads + LengthOfStartAndEndBelt
end

StorageMap = AssignCorridors(StorageMap)
# total length of conveyors in the entire warehouse
ConveyorsLength = TotalLengthOfConveyors(StorageMap)
# mass of the conveyor in the entire warehouse - length * width * mass per m^2
# chosen model - U0/U0
ConveyorsMass = ConveyorsLength * ConsignmentLength * 1.1
ConsignmentWeightPerMetre = ConsignmentWeight / ConsignmentLength
GoodsConveyedWeight =


function GetEnergyUseMatrix(Map)
    Distances = Tuple.(CartesianIndices(Map) .- CartesianIndex(0,47,0))
    EnergyMatrix = Array{Union{Float64, Nothing}}(nothing, size(Map))
    DecisionMatrix = Array{Union{Float64, Nothing}}(nothing, size(Map))

    
end


function GetDistanceMatrix(Map, Type)
    Distances = Tuple.(CartesianIndices(StorageMap) .- CartesianIndex(0,47,0))
    DistanceMatrix = Array{Union{Float64, Nothing}}(nothing, size(StorageMap))
    if Type == "Decision"
        for i in 1:size(DistanceMatrix)[1], j in 1:size(DistanceMatrix)[2], k in 1:size(DistanceMatrix)[3]
            isnothing(StorageMap[i,j,k]) ?
                DistanceMatrix[i,j,k] = 1.4 * abs(Distances[i,j,k][2]) + 1.4 * (abs(Distances[i,j,k][3])-1) : nothing
        end
    elseif Type == "RealDist"
        for i in 1:size(DistanceMatrix)[1], j in 1:size(DistanceMatrix)[2], k in 1:size(DistanceMatrix)[3]
            isnothing(StorageMap[i,j,k]) ?
                DistanceMatrix[i,j,k] =  1.0 * abs(Distances[i,j,k][1]) + 1.4 * abs(Distances[i,j,k][2]) + 1.4 * (abs(Distances[i,j,k][3])-1) : nothing
        end
    end
    return DistanceMatrix
end

t = GetDistanceMatrix(StorageMap, "Decision")
u = GetDistanceMatrix(StorageMap, "RealDist")
#    if isnothing.

end

# wzdluzne odleglosci sa takie same
DistanceMatrix = Array{Union{Float64, Nothing}}(nothing, size(StorageMap))
a = Tuple.(CartesianIndices(StorageMap) .- CartesianIndex(0,47,0))
for i in 1:size(DistanceMatrix)[1], j in 1:size(DistanceMatrix)[2], k in 1:size(DistanceMatrix)[3]
    isnothing(StorageMap2[i,j,k]) ?
        DistanceMatrix[i,j,k] = 1*abs(a[i,j,k][1]) + 1.4 * abs(a[i,j,k][2]) + 1.4 * (abs(a[i,j,k][3])-1) : nothing
end


a = Tuple.(CartesianIndices(StorageMap2) .- CartesianIndex(0,32,0))

isnothing.(StorageMap2)
size(StorageMap2[:,:,1])


[println(i%3) for i in 1:size(StorageMap,2)]
abc = CartesianIndices(StorageMap2)



m = repeat([Any, 1, Any], 30)

m[1] = 12
StorageMap = repeat(['a','b'], 3)
[Any, 'a', Any]



CartesianIndices(StorageMap)
StorageMap[:,1,1]
LinearIndices(StorageMap)

sum(LinearIndices)
