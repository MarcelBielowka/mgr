@rlibrary aTSA
test = Redemption["WindTempDataNoMissing"]

test2 = filter(row -> (row.month .== 6), test)
test3 = filter(row -> (row.month .== 5 && row.year == 2019), test)
test4 = filter(row -> (row.year == 2019), test)

plot1 = plot(test2.date[test2.year .== 2016], test2.WindSpeed[test2.year .== 2016])
plot2 = plot(test2.date[test2.year .== 2017], test2.WindSpeed[test2.year .== 2017])
plot3 = plot(test2.date[test2.year .== 2018], test2.WindSpeed[test2.year .== 2018])
plot4 = plot(test2.date[test2.year .== 2019], test2.WindSpeed[test2.year .== 2019])
plot5 = plot(test.date[(test.year .> 2018) .& (test.month .==6)], test.WindSpeed[(test.year .> 2018) .& (test.month .==6)])

plot(plot1, plot2, plot3, plot4, layout = (2,2))

test5 = filter(row -> (row.date >= Dates.DateTime("2019-01-15") && row.date <= Dates.DateTime("2019-01-31")), test)
testDist = fitdistr(test5.WindSpeed[test5.WindSpeed.>0], "weibull")
histogram(test5.WindSpeed, normalize = true, bins = 30)
plot!(Weibull(testDist[1][1], testDist[1][2]))
ExactOneSampleKSTest(test5.WindSpeed[test5.WindSpeed.>0],
    Weibull(testDist[1][1], testDist[1][2]))

HypothesisTests.ADFTest(Redemption["WindTempDataNoMissing"].WindSpeed, :trend, 24)
HypothesisTests.ADFTest(test.WindSpeed, :squared_trend, 24)
HypothesisTests.ADFTest(diff(test4.WindSpeed), :constant, 24)
HypothesisTests.ADFTest(diff(test3.Temperature), :squared_trend, 24)
plot(test3.date, (test3.WindSpeed))
plot(test3.date[2:size(test3)[1]], diff(test3.WindSpeed))
mymonth = 6
test6 = filter(row -> (row.month .== mymonth && row.year == 2019), test)
plot(test6.date, test6.WindSpeed, title = mymonth)
HypothesisTests.ADFTest(test6.WindSpeed, :constant, 24)
plot(test3.date[2:size(test3)[1]], diff(test3.Temperature))
plot(test3.date, diff(test3.Temperature))

abc = R"tseries::adf.test"(test6.WindSpeed)
xzy = R"tseries::kpss.test"(test6.WindSpeed)
(size(test6)[1]-1)^(1/3)
