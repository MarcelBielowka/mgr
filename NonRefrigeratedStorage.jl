using Pipe: @pipe
using DataStructures, Random, Distributions, StatsPlots, DataFrames
using Distributed

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

function GetInitialConsDataFrame(StorageID, SimLength, LightningEnergyConsumption)
    Hours = repeat([i for i in 0:23], SimLength)
    Days = repeat([1], 24)
    for i in 2:SimLength
        Days = vcat(Days, repeat([i], 24))
    end
    ConsumptionLightning = repeat([LightningEnergyConsumption], length(Hours))
    InitialDataFrame = DataFrames.DataFrame(
        ID = repeat([Int(StorageID)], length(Hours)),
        Day = Days,
        Hour = Hours,
        ConsumptionIn = zeros(length(Hours)),
        ConsumptionOut = zeros(length(Hours)),
        ConsumptionLightning = ConsumptionLightning
    )
    return InitialDataFrame
end


##################################
###### Conveyor constructor ######
##################################
mutable struct Conveyor
    ConveyorSectionLength::Float64
    ConveyorSectionWidth::Float64
    ConveyorUnitMass::Float64
    ConveyorEfficiency::Float64
    FrictionCoefficient::Float64
    StorageSlotHeight::Float64
end

function GetConveyor(ConveyorSectionLength::Float64, ConveyorSectionWidth::Float64,
        ConveyorUnitMass::Float64, ConveyorEfficiency::Float64,
        FrictionCoefficient::Float64, StorageSlotHeight::Float64)
    Conveyor(
        ConveyorSectionLength,
        ConveyorSectionWidth,
        ConveyorUnitMass,
        ConveyorEfficiency,
        FrictionCoefficient,
        StorageSlotHeight
    )
end

##################################
####### Storage constructor ######
##################################
mutable struct Storage
    ID::Int
    StorageMap::Array
    DistanceMap::Array
    HandlingRoadString::String
    MaxCapacity::Int16
    Conveyor::Conveyor
    ElectricityConsumption::DataFrame
    DepartureOrder::Queue
    WaitingQueue::Queue
    DispatchedConsignments::Array
end

# Storage constructor
function Storage(ID, SimLength, SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString,
                 ConveyorSectionLength, ConveyorSectionWidth, StorageSlotHeight,
                 FrictionCoefficient, ConveyorEfficiency, ConveyorMassPerM2,
                 LightningEnergyConsumption)
    StorageMap = GetStorageMap(SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString)
    DistanceMap = GetDistanceMap(StorageMap)
    WarehouseMaxCapacity = sum(isnothing.(StorageMap))
    ConveyorUnitMass = ConveyorSectionWidth * ConveyorSectionLength * ConveyorMassPerM2 * 2
    ConveyorSection = GetConveyor(
            ConveyorSectionLength, ConveyorSectionWidth, ConveyorUnitMass,
            ConveyorEfficiency, FrictionCoefficient, StorageSlotHeight
    )
    dfInitCons = GetInitialConsDataFrame(ID, SimLength, LightningEnergyConsumption)
    Storage(
        ID,
        StorageMap,
        DistanceMap,
        HandlingRoadString,
        WarehouseMaxCapacity,
        ConveyorSection,
        dfInitCons,
        Queue{Consignment}(),
        Queue{Consignment}(),
        Consignment[]
    )
end

##################################
##### Consignment constructor ####
##################################
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
    EffectivePull = Storage.Conveyor.FrictionCoefficient * 9.81 * (Weight + Storage.Conveyor.ConveyorUnitMass)
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
function LocateSlot!(Consignment::Consignment, Storage::Storage, PrintLogs::Bool;
    optimise = true)
    # logs
    IDtoprint = (Consignment.DataIn["Day"], Consignment.DataIn["Hour"], Consignment.DataIn["ID"])
    if any(isnothing.(Storage.StorageMap))
        if optimise
            if PrintLogs
                println("Looking for a place for Consignment $IDtoprint")
            end
            DecisionMap = GetDecisionMap(Storage, Consignment)
            location = findfirst(
                isequal(
                    minimum(DecisionMap[isnothing.(Storage.StorageMap)])
                ), DecisionMap
            )
            if PrintLogs
                println(Tuple(location), " slot allocated. The value of decision matrix is ", DecisionMap[location])
            end
        else
            location = rand(findall(isnothing.(Storage.StorageMap)))
            if PrintLogs
                println(Tuple(location), " slot allocated to Consign ", IDtoprint, ". Energy use is not being optimised")
            end
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
        if PrintLogs
            println("There are no more free spaces, consignment $IDtoprint added to waiting line")
        end
        Consignment.EverWaited = true
        enqueue!(Storage.WaitingQueue, Consignment)
    end
end

# Send the consignment away
function ExpediateConsignment!(Storage::Storage,
            Day::Int, Hour::Int, PrintLogs::Bool)
    CurrentCons = dequeue!(Storage.DepartureOrder)
    if PrintLogs
        println(CurrentCons.DataIn, " is leaving the warehouse")
    end
    push!(CurrentCons.DataOut, "Day" => Day)
    push!(CurrentCons.DataOut, "Hour" => Hour)
    push!(Storage.DispatchedConsignments, CurrentCons)
    Storage.StorageMap[CartesianIndex(CurrentCons.Location)] = nothing
    return CurrentCons
end

# initiate a new storage
function CreateNewStorage(ID, SimLength, PrintLogs,
    SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString,
    ConveyorSectionLength, ConveyorSectionWidth, StorageSlotHeight,
    FrictionCoefficient, ConveyorEfficiency, ConveyorMassPerM2,
    ConsignmentLength, ConsignmentWidth, ConsignmentHeight,
    LightningEnergyConsumption,
    DistWeightCon, DistInitFill)

    NewStorage = Storage(ID, SimLength,
        SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString,
        ConveyorSectionLength, ConveyorSectionWidth, StorageSlotHeight,
        FrictionCoefficient, ConveyorEfficiency, ConveyorMassPerM2,
        LightningEnergyConsumption)

    InitFill = NewStorage.MaxCapacity * rand(DistInitFill)

    for ConsNum in 1:InitFill
        CurrentCons = Consignment(
            Dict("Day" => 0, "Hour" => 0, "ID" => ConsNum),
            NewStorage,
            ConsignmentLength, ConveyorSectionWidth, 1.2, min(rand(DistWeightCon), 1500)
        )
        LocateSlot!(CurrentCons, NewStorage, PrintLogs; optimise = false)
    end

    return NewStorage
end

##################################
##### Runner of a single sim #####
# Conveyor model used is 0/VSH MT#
##################################
function SimOneRun(RunID, SimWindow,
    DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict, PrintLogs;
    SlotsLength = 45, SlotsWidth = 51, SlotsHeight = 7,
    ConveyorSectionLength = 1.4, ConveyorSectionWidth = 1.4, ConveyorEfficiency = 0.8,
    StorageSlotHeight = 1.4, ConveyorMassPerM2 = 2.2,
    ConsignmentLength = 1.2, ConsignmentWidth = 0.8, ConsignmentHeight = 1.2,
    FrictionCoefficient = 0.33,  HandlingRoadString = "||",
    LightningMinimum = 150, LightningLampLumenPerW = 60, LightningLampWork = 150,
    ITPowerConsumption = 2.153)

    # Additional consigns to send - any demand that was not met the previous hour
    AdditionalConsignsToSend = 0

    # Area of the storage
    # Needed for lightning calculation - to be added to the consumption across all days at the end of the run
    # as per lightning norm PN-EN 12464-1:2004: 20 lx = 20 lm/m2
    StorageArea = SlotsLength * ConveyorSectionWidth * SlotsWidth * ConveyorSectionLength + 2 * SlotsWidth * ConveyorSectionLength
    LightningLampLumen = LightningLampLumenPerW * LightningLampWork
    NumberOfLamps = ceil(StorageArea * LightningMinimum / LightningLampLumen)
    ITPowerConsumptionHourly = ITPowerConsumption * StorageArea / 8760
    LightningEnergyConsumption = NumberOfLamps * LightningLampWork / 1000 + ITPowerConsumptionHourly
    # LightningEnergyConsumption = NumberOfLamps * LightningLampWork / 1000
    println("In the new storage there will be $NumberOfLamps lamps using $LightningEnergyConsumption kW of power (this also includes IT systems).")

    # History of consignments coming in and out
    dfConsignmentNumberHistory = DataFrame(
        Day = Int[],
        Hour = Int[],
        ConsignmentsIn = [],
        ConsignmentsOut = [],
    )

    # Initiate a new storage
    NewStorage = CreateNewStorage(RunID, SimWindow, PrintLogs,
        SlotsLength, SlotsWidth, SlotsHeight, HandlingRoadString,
        ConveyorSectionLength, ConveyorSectionWidth, StorageSlotHeight,
        FrictionCoefficient, ConveyorEfficiency, ConveyorMassPerM2,
        ConsignmentLength, ConsignmentWidth, ConsignmentHeight,
        LightningEnergyConsumption,
        DistWeightCon, DistInitFill)
    println("New warehouse is created. Dimensions are: $SlotsLength x $SlotsWidth x $SlotsHeight and the maximum capacity is ", NewStorage.MaxCapacity)

    # Simulation - for each day and each hour
    for Day in 1:1:SimWindow
        println("Day $Day")
        if !(Day % 7 == 6 || Day % 7 == 0)
            println("Workday. Consignments will be coming")
            for Hour in 0:1:23
                if PrintLogs
                    println("Hour $Hour")
                end
                # Get the number of the incoming and departing consignments
                DistNumConsIn = Distributions.Poisson(ArrivalsDict[Hour])
                DistNumConsOut = Distributions.Poisson(DeparturesDict[Hour])
                NumConsIn = rand(DistNumConsIn)
                NumConsOut = rand(DistNumConsOut) + AdditionalConsignsToSend
                AdditionalConsignsToSend = 0
                if PrintLogs
                    println("There are $NumConsIn new consignments coming in and $NumConsOut going out")
                end
                push!(dfConsignmentNumberHistory, (Day, Hour, NumConsIn, NumConsOut))

                # Departure section
                if NumConsOut == 0
                    # if there are no consignments to be sent, nothing happens
                    if PrintLogs
                        println("No consignments are sent out")
                    end
                else
                    # otherwise, we check if there are any consignments in the warehouse
                    for ConsOutID in 1:NumConsOut
                        if any(isa.(NewStorage.StorageMap, Consignment))
                            # if there are, send them
                            if PrintLogs
                                println("Consignment $ConsOutID")
                            end
                            ExpediatedConsign = ExpediateConsignment!(NewStorage, Day, Hour, PrintLogs)
                            NewStorage.ElectricityConsumption[(NewStorage.ElectricityConsumption.Day .==Day) .&
                                (NewStorage.ElectricityConsumption.Hour .==Hour), "ConsumptionOut"] .+= ExpediatedConsign.EnergyConsumption["Out"]
                        else
                            # if not, add the unmet demand to the next hour
                            if PrintLogs
                                println("There are no more consignments in the warehouse")
                            end
                            AdditionalConsignsToSend += 1
                        end
                    end
                end

                # Arrival section
                # If there are some consignments which did not fit in the previous hour
                # check, if they can fit in now
                if length(NewStorage.WaitingQueue) > 0
                    LoopEnd = min(length(NewStorage.WaitingQueue), sum(isnothing.(NewStorage.StorageMap)))
                    if PrintLogs
                        println("$LoopEnd consignments are coming from the queue")
                    end
                    for ConsWait in 1:LoopEnd
                        if PrintLogs
                            println(ConsWait)
                        end
                        ConsignFromQueue = dequeue!(NewStorage.WaitingQueue)
                        LocateSlot!(ConsignFromQueue, NewStorage, PrintLogs)
                        NewStorage.ElectricityConsumption[(NewStorage.ElectricityConsumption.Day .==Day) .&
                            (NewStorage.ElectricityConsumption.Hour .==Hour), "ConsumptionIn"] .+= ConsignFromQueue.EnergyConsumption["In"]
                    end
                end

                # New consignments
                if NumConsIn == 0
                    # if there are no new consignments, nothing happens
                    if PrintLogs
                        println("No consignments are admitted")
                    end
                else
                    # OTherwise, create them and add to the warehouse
                    for ConsInID in 1:NumConsIn
                        CurrentCons = Consignment(
                            Dict("Day" => Day, "Hour" => Hour, "ID" => ConsInID),
                            NewStorage, 1.2, 0.8, 1.2, min(rand(DistWeightCon), 1500)
                        )
                        LocateSlot!(CurrentCons, NewStorage, PrintLogs)
                        NewStorage.ElectricityConsumption[(NewStorage.ElectricityConsumption.Day .==Day) .&
                            (NewStorage.ElectricityConsumption.Hour .==Hour), "ConsumptionIn"] .+= CurrentCons.EnergyConsumption["In"]
                    end
                end
            end
            println("At EOD $Day ", sum(isnothing.(NewStorage.StorageMap)), " free slots remain")
        else
            println("This is a weekend day. No consignments are coming")
            dfConsignmentNumberHistory = vcat(dfConsignmentNumberHistory, DataFrame(
                                                                            Day = repeat([Day], 24),
                                                                            Hour = collect(0:1:23),
                                                                            ConsignmentsIn = repeat([0],24),
                                                                            ConsignmentsOut = repeat([0],24),
                                                                        )
            )
        end
    end
    # returning the outcome
    return Dict(
        "Storage" => NewStorage,
        "ConsignmentsHistory" => dfConsignmentNumberHistory
    )
end

##################################
###### Parallel sim wrapper ######
##################################
function SimWrapper(params)
    RunID, SimWindow, PrintLogs = params
    return SimOneRun(RunID, SimWindow, DistWeightCon, DistInitFill, ArrivalsDict, DeparturesDict, PrintLogs)
end

##################################
##### Helpers data extractor #####
##################################
function AggregateWarehouseConsumptionDataForMonth(iMonth::Int, iYear::Int,
    dfOutput::DataFrame)

    dFirstDayOfMonth = Dates.Date(string(iYear, "-", iMonth, "-01"))
    iDayOfWeekOfFDOM = Dates.dayofweek(dFirstDayOfMonth)
    iDaysInMonth = Dates.daysinmonth(dFirstDayOfMonth)

    dfWarehouseConsumptionMonthly = filter(
        row -> (row.Day >= iDayOfWeekOfFDOM && row.Day < iDayOfWeekOfFDOM + iDaysInMonth),
        dfOutput
    )
    insertcols!(dfWarehouseConsumptionMonthly,
        :month => repeat([iMonth], nrow(dfWarehouseConsumptionMonthly)),
        :DayOfWeek => dfWarehouseConsumptionMonthly.Day .% 7)

    #filter!(row -> row.Day <= Dates.daysinmonth(dFirstDayOfMonth), dfUnorderedWarehouseData)
    return dfWarehouseConsumptionMonthly
end

function AggregateWarehouseConsumptionData(dfOutput::DataFrame,
    iNumberOfWarehouses::Int, iYear::Int, WeatherData::WeatherDataHandler,
    iHeatCoefficient::Float64, iInsideTemp::Float64;
    SlotsLength = 45, SlotsWidth = 51, SlotsHeight = 7,
    ConveyorSectionLength = 1.4, ConveyorSectionWidth = 1.4,
    StorageSlotHeight = 1.4)
    dfFinalConsumption = AggregateWarehouseConsumptionDataForMonth(1, iYear, dfOutput)

    WallSurface = (SlotsLength * ConveyorSectionWidth * SlotsWidth * ConveyorSectionLength +
        2 * SlotsWidth * ConveyorSectionLength) +
        2 * (StorageSlotHeight * SlotsHeight * SlotsWidth * ConveyorSectionLength) +
        2 * (StorageSlotHeight * SlotsHeight * SlotsLength * ConveyorSectionWidth +
            StorageSlotHeight * SlotsHeight * ConveyorSectionWidth * 2)

    for month in 2:12
        dfMonthlyData = AggregateWarehouseConsumptionDataForMonth(month, iYear, dfOutput)
        dfFinalConsumption = vcat(dfFinalConsumption, dfMonthlyData)
    end
    iConsumptionForHeatFluxes =
        abs.(WeatherData.dfWeatherData.Temperature .- iInsideTemp) .* iHeatCoefficient .* WallSurface./1000
    iConsumptionForHeatFluxes = vcat(iConsumptionForHeatFluxes[1], iConsumptionForHeatFluxes)
    dfFinalConsumption.Consumption .+= iConsumptionForHeatFluxes
    dfFinalConsumption.Consumption .*= iNumberOfWarehouses
    return dfFinalConsumption
end

##################################
###### Final data extractor ######
##################################
function ExtractFinalStorageData(OutputDictionary,
    iNumberOfWarehouses::Int, iYear::Int, WeatherData::WeatherDataHandler,
    iHeatCoefficient::Float64, iInsideTemp::Float64;
    SlotsLength = 45, SlotsWidth = 51, SlotsHeight = 7,
    ConveyorSectionLength = 1.4, ConveyorSectionWidth = 1.4,
    StorageSlotHeight = 1.4)
    dfOutputDataSample = OutputDictionary[1]["Storage"].ElectricityConsumption
    dfConsignmentsHistorySample = OutputDictionary[1]["ConsignmentsHistory"]
    for i in 2:length(OutputDictionary)
        dfOutputDataSample = vcat(dfOutputDataSample, OutputDictionary[i]["Storage"].ElectricityConsumption)
        dfConsignmentsHistorySample = vcat(dfConsignmentsHistorySample, OutputDictionary[i]["ConsignmentsHistory"])
    end

    insertcols!(dfOutputDataSample, :ConsumptionTotal =>
        dfOutputDataSample.ConsumptionIn .+ dfOutputDataSample.ConsumptionOut .+ dfOutputDataSample.ConsumptionLightning)
    dfOutputData = @pipe groupby(dfOutputDataSample, [:Day, :Hour]) |>
        combine(_, :ConsumptionTotal => mean => :Consumption,
                    :ConsumptionTotal => std => :ConsumptionSampleStd,
                    nrow => :Counts)
    insertcols!(dfOutputData, :ConsumptionStd => dfOutputData.ConsumptionSampleStd./sqrt.(dfOutputData.Counts))
    select!(dfOutputData, [:Day, :Hour, :Consumption, :ConsumptionStd])

    dfConsignmentsHistory = @pipe groupby(dfConsignmentsHistorySample, [:Day, :Hour]) |>
        combine(_, :ConsignmentsIn => mean => :ConsignmentIn,
                   :ConsignmentsIn => std => :ConsignmentInStdSample,
                   :ConsignmentsOut => mean => :ConsignmentOut,
                   :ConsignmentsOut => std => :ConsignmentOutStdSample,
                   nrow => :Counts
            )
    insertcols!(dfConsignmentsHistory,
        :ConsignmentInStd => dfConsignmentsHistory.ConsignmentInStdSample ./ sqrt.(dfConsignmentsHistory.Counts),
        :ConsignmentOutStd => dfConsignmentsHistory.ConsignmentOutStdSample ./ sqrt.(dfConsignmentsHistory.Counts)
    )
    select!(dfConsignmentsHistory, [:Day, :Hour, :ConsignmentIn, :ConsignmentOut, :ConsignmentInStd, :ConsignmentOutStd])

    dfWarehouseEnergyConsumptionYearly = AggregateWarehouseConsumptionData(dfOutputData,
        iNumberOfWarehouses, iYear, WeatherData, iHeatCoefficient, iInsideTemp)

    return Dict(
        "dfWarehouseEnergyConsumption" => dfOutputData,
        "dfWarehouseEnergyConsumptionYearly" => dfWarehouseEnergyConsumptionYearly,
        "dfConsignmenstHistory" => dfConsignmentsHistory,
        "ExampleStorage" => OutputDictionary[1]["Storage"]
    )

end
