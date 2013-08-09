run2 <- read.csv('objectiveFunctionOuput2.csv', as.is=T)
run3 <- read.csv('objectiveFunctionOuput3.csv', as.is=T)

utn <- names(run2)[1:20]
brmn <- names(run2)[21:38]
rban <- names(run2)[39:47]

names <- c(utn, rban, brmn)

names(run2) <- names
names(run3) <- names

twothree <- rbind(run2, run3)

write.table(x=twothree, file='two_and_three.csv', sep=',', row.names=F, col.names=T)

all <- read.csv('all_results.csv', as.is=T)
first_set <- all[,c(7,8,9,10,12,13,14,3,5,37,25)]
write.table(x=first_set, file='first_set.csv', sep=',', row.names=F, col.names=T)

library(ggplot2)
library(reshape2)
data <- all
qplot(data=data, x=assembly_id, y=rba_query_hits, geom=line)
ggplot(data=data, aes(x=assembly_id, y=rba_query_hits)) +
  geom_line()