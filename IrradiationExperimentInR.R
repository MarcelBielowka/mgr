rm(list=ls())
library(dplyr)
library(lubridate)
library(ggplot2)
library(reshape2)
library(tseries)
source("SolarAngle.R")

# wczytanie i przygotowanie danych
# dane nt promieniowania
dfDataIrr = read.csv("C:/Users/Marcel/Desktop/mgr/data/weather_data_irr.csv")
dfDataIrr = dfDataIrr[,c("date", "prom_avg")]

# dane nt predkosci wiatru i temp
dfDataWind = read.csv("C:/Users/Marcel/Desktop/mgr/data/weather_data_temp_wind.csv")
dfDataWind = dfDataWind[,c("date", "temp_avg", "predkosc100m_avg")]

# polaczenie dwoch zbiorow
dfWeatherData = dplyr::inner_join(dfDataWind, dfDataIrr, by = "date")
# zmiana nazw kolumn i typow danych
colnames(dfWeatherData) = c("date", "Temperature", "WindSpeed", "Irradiation")
dfWeatherData$date = as.character(dfWeatherData$date) %>% as.POSIXct(., format = "%Y-%m-%d %H:%M:%S")

# rekodowanie zmiennych
dfWeatherData$WindSpeed[dfWeatherData$WindSpeed == Inf] = NA
dfWeatherData = na.omit(dfWeatherData)

# dodatkowe zmienne
dfWeatherData$date_nohour = as.POSIXct(dfWeatherData$date)
dfWeatherData$month = lubridate::month(dfWeatherData$date)
dfWeatherData$hour = lubridate::hour(dfWeatherData$date)
dfWeatherData = dfWeatherData[dfWeatherData$date > 
                                as.POSIXct("2018-12-31 23:59:59", format = "%Y-%m-%d %H:%M:%S"),]

# Clear sky irradiation - based on McClear model from Copernicus AMS
dfClearSkyIrr = read.csv("C:/Users/Marcel/Desktop/mgr/data/clear_sky_irradiation_CAMS.csv", sep = ";", skip = 37)
colnames(dfClearSkyIrr) = c("Date", "TOA", "GHI", "BHI", "DHI", "BNI")
dfClearSkyIrr$Date = as.character(dfClearSkyIrr$Date)
# get only data from 2019
dfClearSkyIrr = dfClearSkyIrr[grepl("2019", dfClearSkyIrr$Date),]
dfClearSkyIrr$date = as.POSIXct("1900-01-01 01:00:00")
# get dates to date format
for (i in 1:nrow(dfClearSkyIrr)) {
  t = (strsplit(dfClearSkyIrr$Date[i], split = "/") %>% unlist())[1]
  t = strsplit(t, split = "T") %>% unlist() %>% paste(., collapse = " ")
  t = substr(t, 1, nchar(t)-2)
  # print(t)
  as.POSIXct(t, format = "%Y-%m-%d %H:%M:%S")
  dfClearSkyIrr$date[i] = t
}
View(dfClearSkyIrr)

# take only interesting columns and join two datasets
dfClearSkyIrr = dfClearSkyIrr[,c("date", "TOA", "GHI", "BHI", "DHI", "BNI")]
dfData = dplyr::left_join(dfWeatherData, dfClearSkyIrr, by = "date")
# Initiate slear sky and clearness indices
dfData$SunElevation = sunPosition(year = year(dfData$date_nohour),
                                  month = month(dfData$date_nohour),
                                  day = day(dfData$date_nohour),
                                  hour = hour(dfData$date_nohour))$elevation
dfData$Irradiation[dfData$SunElevation < 10] = 0
dfData$ClearSkyIndex = 0
dfData$ClearSkyIndexHigherThreshold = 0
dfData$ClearnessIndex = 0
dfData$ClearnessIndexHigherThreshold = 0

# Clear Sky Indices
dfData$ClearSkyIndex[dfData$Irradiation > 0] = dfData$Irradiation[dfData$Irradiation > 0]/dfData$GHI[dfData$Irradiation > 0]
#dfData$ClearSkyIndex[dfData$GHI > 0.1] = dfData$Irradiation[dfData$GHI > 0.1] / dfData$GHI[dfData$GHI > 0.1]

#dfData$ClearSkyIndexHigherThreshold[dfData$GHI > 2] = 
#    dfData$Irradiation[dfData$GHI > 2] / dfData$GHI[dfData$GHI > 2]

# Clearness Indices
# dfData$ClearnessIndex[dfData$TOA > 0.1] = dfData$Irradiation[dfData$TOA > 0.1] / dfData$TOA[dfData$TOA > 0.1]
dfData$ClearnessIndex[dfData$Irradiation > 0] = dfData$Irradiation[dfData$Irradiation > 0]/dfData$TOA[dfData$Irradiation > 0]

# dfData$ClearnessIndexHigherThreshold[dfData$TOA > 2] = 
    # dfData$Irradiation[dfData$TOA > 2] / dfData$TOA[dfData$TOA > 2]

# summary
dfData = dfData[,c("date", "Irradiation", "GHI", "TOA", "ClearSkyIndex", "ClearSkyIndexHigherThreshold", "ClearnessIndex", "ClearnessIndexHigherThreshold"),]
dfData$month = month(dfData$date)
dfData$hour = hour(dfData$date)
# Clear Sky above 1
nrow(dfData[dfData$ClearSkyIndex>1,])
nrow(dfData[dfData$ClearSkyIndexHigherThreshold>1,])

# Clearness above 1
nrow(dfData[dfData$ClearnessIndex>1,])
nrow(dfData[dfData$ClearnessIndexHigherThreshold>1,])

# Lowest 20 and highest 100 - clear sky
dfDataLowest20 = dfData %>% arrange(ClearSkyIndex) %>% head(.,20)
View(dfDataLowest20)
dfDataHighest100 = dfData %>% arrange(desc(ClearSkyIndex)) %>% head(.,100)
View(dfDataHighest100)
dfDataHighest100HigherThreshold = dfData %>% arrange(desc(ClearSkyIndexHigherThreshold)) %>% head(.,100)
View(dfDataHighest100HigherThreshold)
View(dfData[dfData$ClearSkyIndexHigherThreshold>1,])

# Lowest 20 and highest 100 - clearness
dfDataLowest20Clearness = dfData %>% arrange(ClearnessIndex) %>% head(.,20)
View(dfDataLowest20Clearness)
dfDataHighest100Clearness = dfData %>% arrange(desc(ClearnessIndex)) %>% head(.,100)
View(dfDataHighest100Clearness)
dfDataHighest100HigherThresholdClearness = dfData %>% arrange(desc(ClearnessIndexHigherThreshold)) %>% head(.,100)
View(dfDataHighest100HigherThresholdClearness)


## Visualisation - clear sky index
FreqTable = table(dfData$hour[dfData$ClearSkyIndex>1], dfData$month[dfData$ClearSkyIndex>1])
FreqTableMelted = reshape2::melt(FreqTable, value.name = "Freqs")
FreqTableMelted$Freqs[FreqTableMelted$Freqs == 0] = NA
ggplot2::ggplot(data = FreqTableMelted) + 
  aes(x = factor(Var2), y = factor(Var1), fill = Freqs) + 
  geom_tile() + 
  xlab("Months") + ylab("Hours") + 
  scale_fill_gradient(low = rgb(192, 192, 192, max = 255), high = rgb(60, 0, 0, max = 255), 
                      na.value = "white") + 
  ggtitle("Cases exceeding 1, clear sky index") +
  theme_classic() +
  theme(plot.title = element_text(hjust = 0.5))


## Visualisation - clearness index
FreqTableClearness = table(dfData$hour[dfData$ClearnessIndex>1], dfData$month[dfData$ClearnessIndex>1])
FreqTableClearnessMelted = reshape2::melt(FreqTableClearness, value.name = "Freqs")
FreqTableClearnessMelted$Freqs[FreqTableClearnessMelted$Freqs == 0] = NA
ggplot2::ggplot(data = FreqTableClearnessMelted) + 
  aes(x = factor(Var2), y = factor(Var1), fill = Freqs) + 
  geom_tile() + 
  xlab("Months") + ylab("Hours") + 
  scale_fill_gradient(low = rgb(192, 192, 192, max = 255), high = rgb(60, 0, 0, max = 255), 
                      na.value = "white") + 
  ggtitle("Cases exceeding 1, clearness index") +
  theme_classic() +
  theme(plot.title = element_text(hjust = 0.5))
