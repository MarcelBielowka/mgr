#FlatMicrogrid = GetMicrogrid(DayAheadPowerPrices, Weather,
#    MyWindPark, MyWarehouse, Households, "sigmoid", 2)
#FlatMicrogrid.Brain.memory
#RandomMicrogrid = GetMicrogrid(DayAheadPowerPrices, Weather,
#    MyWindPark, MyWarehouse, Households, "identity", 0)
# so far the winning formula - Nov, 2-step look ahead
MyMicrogrid = GetMicrogrid(DayAheadPowerPrices, Weather,
    MyWindPark, MyWarehouse, Households, "identity", 2,
    0.0001, 0.001, 0.99)
RandomMicrogrid = deepcopy(MyMicrogrid)
#MyMicrogrid = GetMicrogrid(DayAheadPowerPrices, Weather,
#     MyWindPark, MyWarehouse, Households, "sigmoid", 2)
Flux.params(MyMicrogrid.Brain.policy_net)
Flux.params(MyMicrogrid.Brain.value_net)
RandomMicrogrid.Brain.memory = []
#Flux.params(MyMicrogrid.Brain.policy_net) |> sum |> sum
# dobrze - , luty, maj, lipiec, sierpien, wrzesien, pazdziernik
# zle - styczen, marzec, kwiecien, czerwiec, listopad, grudzien
# grudzien - brak poprawy przy wiekszej liczbie WF, nie wychodzi ze startu
# listopad - brak poprawy przy wiekszej liczbie WF, uczenie bardzo niestabilne
# czerwiec - brak pooprawy przy wiekszej liczbie WF i storage'u
# kwiecien - brak poprawz
dRunStartTrain = @pipe Dates.Date("2019-04-01") |> Dates.dayofyear |> _*24 |> _- 23
dRunEndTrain = @pipe Dates.Date("2019-09-30") |> Dates.dayofyear |> _*24 |> _-1
dRunStartTest = dRunEndTrain + 1
dRunEndTest = @pipe Dates.Date("2019-12-30") |> Dates.dayofyear |> _*24 |> _-1
iEpisodeLength = dRunStartTest - dRunEndTest |> abs
iEpisodeLengthTrain = dRunStartTrain - dRunEndTrain |> abs
MyMicrogrid.Brain
a = 2
MyMicrogrid.EnergyStorage
RandomMicrogrid.Brain.memory
InitialTestResult = Run!(RandomMicrogrid, 1, 2, 70, 50, dRunStartTest, dRunEndTest, false, false)
@time TrainResult = Run!(MyMicrogrid, 1, 2, 70, 50, dRunStartTrain, dRunEndTrain, true, true)
iLookBack = 2
iEpisodes = length(MyMicrogrid.RewardHistory)
plot(MyMicrogrid.RewardHistory, legend = :none, title = "Learning history, look forward = $iLookBack, $iEpisodes episodes")
FinalMicrogrid = deepcopy(MyMicrogrid)
FinalMicrogrid.Brain.memory = []
FinalMicrogrid.RewardHistory = []
TestResultAfterTraining = Run!(FinalMicrogrid, 100, 2, dRunStartTest, dRunEndTest, false, false)

MyMicrogrid.Brain.value_net(MyMicrogrid.State)

MeanBefore, VarBefore = mean(InitialTestResult[1]), var(InitialTestResult[1])
MeanAfter, VarAfter = mean(TestResultAfterTraining[1]), var(TestResultAfterTraining[1])

plot(InitialTestResult[1], label = "Initial", title = "Results: learned vs random")
plot!(TestResultAfterTraining[1], label = "After training")

Zscore = (MeanBefore - MeanAfter) / (sqrt(VarBefore/100 + VarAfter/100))
pdf(Distributions.Normal(0,1), Zscore)

iMismatch = [FinalMicrogrid.Brain.memory[i][1][1] for i in 1:length(FinalMicrogrid.Brain.memory)]
#iSign = [FinalMicrogrid.Brain.memory[i][1][length(FinalMicrogrid.State)-1] for i in 1:length(FinalMicrogrid.Brain.memory)]
#iMismatch[iSign .== 1] .*= -1
iVolLoaded = [FinalMicrogrid.Brain.memory[i][3] for i in 1:length(FinalMicrogrid.Brain.memory)] .* iMismatch
# iVolLoaded = [FinalMicrogrid.Brain.memory[i][3] for i in 1:length(FinalMicrogrid.Brain.memory)] .* iMismatch
iBatteryCharge = [FinalMicrogrid.Brain.memory[i][1][length(FinalMicrogrid.State)] for i in 1:length(FinalMicrogrid.Brain.memory)] .* FinalMicrogrid.EnergyStorage.iMaxCapacity#
iDecision = [FinalMicrogrid.Brain.memory[i][3] for i in 1:length(FinalMicrogrid.Brain.memory)]

iMismatchRandom = [RandomMicrogrid.Brain.memory[i][1][1] for i in 1:length(RandomMicrogrid.Brain.memory)]
#iRandomSign = [RandomMicrogrid.Brain.memory[i][1][length(RandomMicrogrid.State)-1] for i in 1:length(RandomMicrogrid.Brain.memory)]
#iMismatchRandom[iRandomSign .== 1] .*= -1
iVolLoadedRandom = [RandomMicrogrid.Brain.memory[i][3] for i in 1:length(RandomMicrogrid.Brain.memory)] .* iMismatchRandom
# iVolLoadedRandom = [RandomMicrogrid.Brain.memory[i][3] for i in 1:length(RandomMicrogrid.Brain.memory)] .* iMismatchRandom
iBatteryChargeRandom = [RandomMicrogrid.Brain.memory[i][1][length(RandomMicrogrid.State)] for i in 1:length(RandomMicrogrid.Brain.memory)] .* RandomMicrogrid.EnergyStorage.iMaxCapacity

iMismatchTrain = [MyMicrogrid.Brain.memory[i][1][1] for i in 1:length(MyMicrogrid.Brain.memory)]
#iSignTrain = [MyMicrogrid.Brain.memory[i][1][length(MyMicrogrid.State)-1] for i in 1:length(MyMicrogrid.Brain.memory)]
#iMismatchTrain[iSignTrain .== 1] .*= -1
iVolLoadedTrain = [MyMicrogrid.Brain.memory[i][3] for i in 1:length(MyMicrogrid.Brain.memory)] .* iMismatchTrain
# iVolLoadedTrain = [MyMicrogrid.Brain.memory[i][3] for i in 1:length(MyMicrogrid.Brain.memory)] #.* MyMicrogrid.EnergyStorage.iMaxCapacity
iBatteryChargeRandom = [MyMicrogrid.Brain.memory[i][1][length(MyMicrogrid.State)] for i in 1:length(MyMicrogrid.Brain.memory)] .* MyMicrogrid.EnergyStorage.iMaxCapacity

iMismatch[length(FinalMicrogrid.Brain.memory)-11:length(FinalMicrogrid.Brain.memory)-1]

plot(iMismatch[length(FinalMicrogrid.Brain.memory)-(iEpisodeLength+1):length(FinalMicrogrid.Brain.memory)-1], label = "Prod/cons mismatch")
plot(iMismatch[length(FinalMicrogrid.Brain.memory)-(iEpisodeLength+1):length(FinalMicrogrid.Brain.memory)-1], label = "Prod/cons mismatch",
    ylim = (-200, 1000))
plot!(iVolLoaded[length(FinalMicrogrid.Brain.memory)-(iEpisodeLength+1):length(FinalMicrogrid.Brain.memory)-1], label = "Actions taken")
plot!(iBatteryCharge[length(FinalMicrogrid.Brain.memory)-iEpisodeLength:length(FinalMicrogrid.Brain.memory)-1], label = "Battery charge")
plot(iDecision[length(FinalMicrogrid.Brain.memory)-215:length(FinalMicrogrid.Brain.memory)])


plot(iMismatchRandom[length(RandomMicrogrid.Brain.memory)-215:length(RandomMicrogrid.Brain.memory)],
    label = "Prod/cons mismatch")
plot!(iVolLoadedRandom[length(RandomMicrogrid.Brain.memory)-(iEpisodeLength+1):length(RandomMicrogrid.Brain.memory)-1], label = "Actions taken, random")
plot!(iBatteryChargeRandom[length(RandomMicrogrid.Brain.memory)-iEpisodeLength:length(RandomMicrogrid.Brain.memory)], label = "Battery charge, random")


plot(iMismatchTrain[length(MyMicrogrid.Brain.memory)-415:length(MyMicrogrid.Brain.memory)], label = "Prod/cons mismatch, train set")
plot(iMismatchTrain[length(MyMicrogrid.Brain.memory)-477:length(MyMicrogrid.Brain.memory)], label = "Prod/cons mismatch, train set",
    ylim = (-100, 400))
plot!(iVolLoadedTrain[length(MyMicrogrid.Brain.memory)-477:length(MyMicrogrid.Brain.memory)], label = "Actions taken")
plot(iMismatchTrain[1:200], label = "Prod/cons mismatch, train set")
plot!(iVolLoadedTrain[1:200], label = "Actions taken")



MyMicrogrid.State
Flux.params(MyMicrogrid.Brain.policy_net[1])

MicrogridHY_2
MicrogridHY_0
plot(MicrogridHY_0.RewardHistory)
FinalMicrogrid_0
FinalMicrogrid_2

MyMicrogrid.Brain.memory
RandomMicrogrid.Brain.memory
FinalMicrogrid.Brain.memory

ItFuckingWorked = deepcopy(MyMicrogrid)
