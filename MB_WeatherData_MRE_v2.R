#### kod wyliczajacy ClearnessIndex na podstawie danych meteo ####
#### linijki 100 - 103 zawieraja wybor  i wyprintowanie (View) ###
#### 20 najwiekszychi i najmniejszych wartosci ClearnessIndex ####


# wgranie bibliotek
library(dplyr)
library(lubridate)

# katalog roboczy
# setwd("C:/Users/Marcel/Desktop/mgr/kody")
rm(list=ls())
source("SolarAngle.R")

# potrzebne funkcje
# theta
GetTheta = function(DayOfYear) {
  theta = 2 * pi * (DayOfYear - 1) / 365
  return(theta)
}

# korekta ekscentrycznosci orbity Ziemi
GetEccentricityCorrection = function(theta) {
  E0 = 1.00011 + 0.034221*cos(theta) + 0.00128*sin(theta) -
    0.000719*cos(2*theta) + 0.000077*sin(2*theta)
  return(E0)
}

# cosinus kata zenitu
GetZenithAngle = function(theta, DayOfYear, HourOfDay, 
                          Latitude = (50 + 17/60), Longitude = (19 + 8/60),
                          LongitudeStandard = 15) {
  # kat deklinacji
  delta = 0.006918 - 0.399912 * cos(theta) + 0.070257 * sin(theta) -                                      # solar declination
    0.006759 * cos(2*theta) +  0.000907 * sin(2*theta) + 0.00148 * sin(3*theta) -
    0.002697 * cos(3*theta)
  
  # rownanie czasu
  Et = 0.000075 + 0.001868 * cos(theta) - 0.032077 * sin(theta) -
    0.14615*cos(2*theta) - 0.04084*sin(2*theta)                                                     # equation of time
  
  # godzina sloneczna
  SolarHour = HourOfDay + (LongitudeStandard-Longitude) / 15 + Et                                           # solar hour
  
  # kat godziny
  omega = 2*pi/24*(SolarHour - 12)                                                                 # hour angle
  
  # zebranie do kata zenitu
  CosZenithAngle = sin(Latitude) * sin(delta) + cos(Latitude) * cos(delta) * cos(omega)
  return(list(
    delta = delta, Et = Et, SolarHour = SolarHour, 
    omega = omega, CosZenithAngle = CosZenithAngle
  )
  )
}

# clearness index
ClearnessIndex = function(IncidentalIrradiance, DayOfYear, HourOfDay,
                          Latitude = (50 + 17/60), Longitude = (19 + 8/60),
                          LongitudeStandard = 15) {  
  theta = GetTheta(DayOfYear)                                                               
  
  E0 = GetEccentricityCorrection(theta)
  
  CosZenithAngle = GetZenithAngle(theta, DayOfYear, HourOfDay)$CosZenithAngle
  
  k = IncidentalIrradiance / (1366 * E0 * CosZenithAngle)
  return(list(k=k, GHI = 1366 * E0 * CosZenithAngle))
}

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
dfWeatherData$GHI  = ClearnessIndex(dfWeatherData$Irradiation,
                                    lubridate::yday(dfWeatherData$date),
                                    dfWeatherData$hour)$GHI
dfWeatherData$ClearnessIndex = ClearnessIndex(dfWeatherData$Irradiation,
                                              lubridate::yday(dfWeatherData$date),
                                              dfWeatherData$hour)$k

dfWeatherData$SunElevation = sunPosition(year = lubridate::year(dfWeatherData$date), 
                                         month = dfWeatherData$month,
                                         day = lubridate::day(dfWeatherData$date),
                                         hour = dfWeatherData$hour)$elevation

# posortowane wyniki
dfWeatherDataLowest20 = dfWeatherData %>% arrange(ClearnessIndex) %>% head(.,20)
View(dfWeatherDataLowest20)
dfWeatherDataHighest100 = dfWeatherData %>% arrange(desc(ClearnessIndex)) %>% head(.,100)
View(dfWeatherDataHighest100)

p = dfWeatherData[dfWeatherData$ClearnessIndex>1,] %>% arrange(desc(ClearnessIndex)) %>% View()

# sprawdzenie - clearness index > 1 i < 0
View(dfWeatherData[dfWeatherData$ClearnessIndex<0,])
View(dfWeatherData[dfWeatherData$ClearnessIndex>1,])
unique(dfWeatherData[dfWeatherData$ClearnessIndex<0,"hour"])
unique(dfWeatherData[dfWeatherData$ClearnessIndex>1,"hour"])
