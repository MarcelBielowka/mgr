using HTTP, LightXML, Dates

PriceDataRequest = HTTP.request("GET","https://transparency.entsoe.eu/api?documentType=A44&In_Domain=10YPL-AREA-----S&Out_Domain=10YPL-AREA-----S&periodStart=201810262300&periodEnd=201810292200&securityToken=3c4152bc-42d0-4b2d-809c-3715d5d1c95d")

PriceDataRequest.headers
PriceDataRequest.status
println(PriceDataRequest.request)

PriceDataXMLBody = String(PriceDataRequest.body)
PriceDataTree = LightXML.parse_string(PriceDataXMLBody)

PriceDataTreeRoot = root(PriceDataTree)
DateStar = PriceDataTreeRoot["period.timeInterval"][1]
a = content(DateStar)
b = split(a, "T")
c = Dates.DateTime(b[1], "yyyy-mm-dd")-Dates.Day(1)

PriceDataArray = PriceDataTreeRoot["TimeSeries"]
abc = PriceDataArray[1]["Period"][1]["Point"]
xyz = PriceDataArray[1]["Period"][1]["timeInterval"][1]
length(abc)
nnn = zeros(0)
for child in child_elements(abc)
    #println(child)
    for child2 in child_elements(child)
    #    println(child2)
    if name(child2) == "price.amount"
        println(content(child2))
        append!(nnn, parse(Float64, content(child2)))
    end
    #m = child["price.amount"]
    #println(typeof(m[1]))
    #println(m)
    #for m in 1:length(m)
    #    a = m[1]
    #    println(m)
    #    println("a = $a")
    #end
    end
end

nnn = zeros(0)
length(nnn)

for i in 1:1:length(PriceDataArray)
    PriceDataDayI = PriceDataArray[i]["Period"][1]     # PriceDataDayI - all prices on day i

    for PriceDataDayChild in child_elements(PriceDataDayI)
        for child in child_elements(PriceDataDayChild)
            if name(child2) == "price.amount"
                println(content(child2))
                append!(nnn, parse(Float64, content(child2)))
            end
        end
    end
end

for c in 1:1:length(PriceDataNode)
    append!(nnn,parse(Float64, content(PriceDataNode[c]["price.amount"][1])))
end

length(nnn)
