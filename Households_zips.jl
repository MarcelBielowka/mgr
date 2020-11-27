using ZipFile, CSV

AllFiles = ZipFile.Reader("C:/Users/Marcel/Desktop/mgr/data/LdnHouseDataSplit.zip")
aaa = AllFiles.files[2].name
split(aaa,"/")
length(split(aaa,"/")[2])

bb = open(AllFiles.files[2].name)


for eachfile in AllFiles.files
    println(eachfile.name)
    if length(split(eachfile.name,"/")[2]) > 0

    else
        println("Skip the file")
    end
    #abc = read(eachfile.name)
end
