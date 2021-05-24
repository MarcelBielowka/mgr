rm(list=ls())
library(httr)
library(xml2)
library(jsonlite)
library(dplyr)

res = httr::GET("https://data.bathhacked.org/api/datasets/18/rows?page=1&per_page=15")
res = httr::GET("https://data.bathhacked.org/api/datasets/18/rows?",
                query = list(
                  page = 1,
                  per_page = 1000
                )
                )
lResponse = jsonlite::fromJSON(rawToChar(res$content))
dfData = lResponse$data

for (i in 2:1670) {
  message("Handling file ", i)
  res = httr::GET("https://data.bathhacked.org/api/datasets/18/rows?",
                  query = list(
                    page = i,
                    per_page = 100
                )
  )
  lResponse = jsonlite::fromJSON(rawToChar(res$content)) 
  dfData = rbind(dfData, lResponse$data)
}

View(dfData)
grep("Council", dfData$location)
t = dfData[grepl("Council", dfData$location),]
t = t[grepl("2019", t$date),]
t = t[order(t$date),]
View(t)
View(dfData[grepl("Library", dfData$location),] %>% order_by(date))
