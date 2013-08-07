data <- read.csv('dataset-no-homogenity-selective.csv', as.is=T, head=T)



loop <- data[which(data$runid<=1),]
plot(loop$iterid, loop$score, type="o", col="blue", ylim=c(min(data$score), max(data$score)), xlim=c(min(data$iterid), max(data$iterid)))
loop <- data[which(data$runid==2),]
lines(loop$iterid, loop$score, type="o", col="red")
loop <- data[which(data$runid==3),]
lines(loop$iterid, loop$score, type="o", col="green")
loop <- data[which(data$runid==4),]
lines(loop$iterid, loop$score, type="o", col="darkgreen")
loop <- data[which(data$runid==5),]
lines(loop$iterid, loop$score, type="o", col="orange")
loop <- data[which(data$runid==6),]
lines(loop$iterid, loop$score, type="o", col="pink")
loop <- data[which(data$runid==7),]
lines(loop$iterid, loop$score, type="o", col="purple")
loop <- data[which(data$runid==8),]
lines(loop$iterid, loop$score, type="o", col="cyan")
loop <- data[which(data$runid==9),]
lines(loop$iterid, loop$score, type="o", col="violet")
loop <- data[which(data$runid==10),]
lines(loop$iterid, loop$score, type="o", col="magenta")

