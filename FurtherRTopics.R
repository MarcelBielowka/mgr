library(dplyr)
library(lubridate)
library(forecast)
library(tseries)

DATA = read.csv("C:/Users/Marcel/Desktop/mgr/data/weather_data_temp_wind.csv")
View(DATA)
DATA$date = as.character(DATA$date)
DATA$date = as.POSIXct(DATA$date, format = "%Y-%m-%d %H:%M:%S")
DATA = na.omit(DATA)

DATA2 = DATA[DATA$date >= as.POSIXct("2017-01-01 00:00:00"),]
DATA_train = DATA2[(DATA2$date >= as.POSIXct("2018-01-01 00:00:00") & DATA2$date < as.POSIXct("2018-11-01 00:00:00")),]
DATA_test = DATA2[(DATA2$date >= as.POSIXct("2018-11-01 00:00:00") & DATA2$date < as.POSIXct("2019-01-01 00:00:00")),]

DATA3 = DATA[year(DATA$date) != 2018,]
adf.test(DATA3$predkosc100m_avg)

model = forecast::Arima(DATA_train$predkosc100m_avg, order = c(4,0,1), optim.method = "Nelder-Mead", optim.control = list(maxit = 10000))
sum(model$coef[1:5])
summary(model)
model_eval = forecast::Arima(DATA_test$predkosc100m_avg, model = model)
summary(model_eval)
model$series
model_eval$fitted
DATA_test$predkosc100m_avg
sqrt(mean((DATA_test$predkosc100m_avg - model_eval$fitted)^2))
mean(DATA_test$predkosc100m_avg - model_eval$fitted)

model_test = forecast::Arima(DATA_train$predkosc100m_avg, order = c(2,0,4), 
                            optim.method = "Nelder-Mead", optim.control = list(maxit = 10000))
summary(model_test)
model_eval_test = forecast::Arima(DATA_test$predkosc100m_avg, model = model_test2)
summary(model_eval_test)

model_test2 = forecast::Arima(DATA_train$predkosc100m_avg, order = c(2,0,4), 
                             optim.method = "Nelder-Mead", optim.control = list(maxit = 10000),
                             fixed = c(NA, NA, NA, 0, NA, 0, NA))
summary(model_test2)
model_eval_test2 = forecast::Arima(DATA_test$predkosc100m_avg, model = model_test)
summary(model_eval_test2)


model_5 = forecast::Arima(DATA_train$predkosc100m_avg, order = c(1,0,4), optim.method = "Nelder-Mead", optim.control = list(maxit = 10000))
summary(model_5)
model_eval_5 = forecast::Arima(DATA_test$predkosc100m_avg, model = model_5)
summary(model_eval_5)
RMSE = 

m = arima(DATA_train$predkosc100m_avg, order = c(1,0,1), optim.method = "Nelder-Mead", optim.control = list(maxit = 10000))
sum(m$coef[-8])
sum((m$coef[-8])^2)
1-sum(model$coef[1:4])
fc = forecast::forecast(model, h = 24)$mean
realised = DATA2[(DATA2$date >= as.POSIXct("2019-01-01 00:00:00") & DATA2$date < as.POSIXct("2019-01-02 00:00:00")),"predkosc100m_avg"]
RMSE = sum((fc-realised)^2) %>% sqrt()

arima(DATA_train$predkosc100m_avg, order = c(5,0,0), optim.method = "Nelder-Mead", optim.control = list(maxit = 10000))


for (p in 0:7) {
  for (q in 0:7) {
    model_train = forecast::Arima(DATA_train$predkosc100m_avg, order = c(p,0,q), optim.method = "Nelder-Mead", optim.control = list(maxit = 10000))
    myAIC = model_train$aic
    model_test = forecast::Arima(DATA_test$predkosc100m_avg, model = model_train)
    RMSE_test = sqrt(mean((DATA_test$predkosc100m_avg - model_test$fitted)^2))
    message("ARMA (", p, ". ", q, "). AIC on train model: ", myAIC, ". RMSE on test model: ", RMSE_test)
  }
}

xx = seq(-1, 1, by = 0.01)
yy = 1 - model$coef[1]*abs(xx) - model$coef[2] * abs(xx)^2 - model$coef[3]*abs(xx)^3 - model$coef[4]*abs(xx)^4
plot(xx, yy)

model_temp_train = forecast::Arima(DATA_train$temp_avg, order = c(1,1,1), optim.method = "Nelder-Mead", optim.control = list(maxit = 10000))
summary(model_temp_train)
model_temp_train_eval = forecast::Arima(DATA_test$temp_avg, model = model_temp_train)
summary(model_temp_train_eval)


pacf(diff(DATA_train$temp_avg))
acf(diff(DATA_train$temp_avg))
View(DATA[DATA$date >= as.POSIXct("2019-01-01 00:00:00"),])
adf.test(diff(DATA$temp_avg[(year(DATA$date)==2018 & month(DATA$date)<11)]))
adf.test(diff(DATA_train$temp_avg))

                       