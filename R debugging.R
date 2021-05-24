library(MASS)
library(dplyr)

a = rbeta(1000, 4, 2, 0)
MASS::fitdistr(a, "beta", start = list(shape1 = 104, shape2 = 3))

DATA = read.csv("C:/Users/Marcel/Desktop/mgr/data/grouped.csv", 
                header = T, sep = ",")

temp = DATA[DATA$hour==13,]
class(temp$promieniowanie_unit)

a = MASS::fitdistr(temp$promieniowanie_unit, "beta", 
               start = list(shape1 = 2, shape2 = 2))