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