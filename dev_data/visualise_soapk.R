data <- read.csv('soapkoptimisation.csv', as.is=T)

library(ggplot2)

# plot DFO for all points
ggplot(data, aes(x=k, y=dr, colour=factor(d))) +
  geom_point() +
  ylab('distance from optimal') +
  scale_color_brewer(palette='Set1', name='100k reads') +
  ggtitle('Dimension-reduced multi objective optimisation of k in soapdenovo assemblies with varying read depth')

# plot time taken for each optimisation (total)
time <- aggregate(time ~ d, data[,c('d', 'time')], sum)

ggplot(time, aes(x=d, y=time/60)) +
  geom_point() +
  xlab('number of reads (x100k)') +
  ylab('time to optimise k for soapdenovo (minutes)') +
  ggtitle('Time taken to sweep + run objective functions for k in soapdenovo with increasing read depth')

# plot distribution of each objective function


# BMRs
data$brms <- sqrt(((0 - data$brm) / 1)**2)
ggplot(data, aes(x=k, y=brms, colour=factor(d))) +
  geom_point() +
  ylab('scaled proportion of bad read mappings') +
  scale_color_brewer(palette='Set1', name='100k reads') +
  ggtitle('Distribution of scaled BRM objective function vs. k in soapdenovo assemblies with varying read depth')

# RBA
ggplot(data, aes(x=k, y=rba, colour=factor(d))) +
  geom_point() +
  ylab('number of conditional annotations') +
  scale_color_brewer(palette='Set1', name='100k reads') +
  ggtitle('Distribution of RBA objective function vs. k in soapdenovo assemblies with varying read depth')

ggplot(data, aes(x=k, y=log(rba), colour=factor(d))) +
  geom_point() +
  ylab('log number of conditional annotations') +
  scale_color_brewer(palette='Set1', name='100k reads') +
  ggtitle('Distribution of log RBA objective function vs. k in soapdenovo assemblies with varying read depth')

data$rbas <- sqrt(((26000 - data$rba) / 26000)**2)
ggplot(data, aes(x=k, y=rbas, colour=factor(d))) +
  geom_point() +
  ylab('scaled no. of conditional annotations') +
  scale_color_brewer(palette='Set1', name='100k reads') +
  ggtitle('Distribution of scaled RBA objective function vs. k in soapdenovo assemblies with varying read depth')

# UT
ggplot(data, aes(x=k, y=ut, colour=factor(d))) +
  geom_point() +
  ylab('number of unexpressed transcripts') +
  scale_color_brewer(palette='Set1', name='100k reads') +
  ggtitle('Distribution of UT objective function vs. k in soapdenovo assemblies with varying read depth')

ggplot(data, aes(x=k, y=log(ut), colour=factor(d))) +
  geom_point() +
  ylab('log number of unexpressed transcripts') +
  scale_color_brewer(palette='Set1', name='100k reads') +
  ggtitle('Distribution of log UT objective function vs. k in soapdenovo assemblies with varying read depth')

data$uts <- sqrt(((0 - data$ut) / max(data$ut))**2)
ggplot(data, aes(x=k, y=uts, colour=factor(d))) +
  geom_point() +
  ylab('scaled no. unexpressed transcripts') +
  scale_color_brewer(palette='Set1', name='100k reads') +
  ggtitle('Distribution of scaled UT objective function vs. k in soapdenovo assemblies with varying read depth')

# contribution of each objective to the DFO
library(reshape2)
contribs <- melt(data=data[data$d==16, c('k', 'dr', 'uts', 'rbas', 'brms')], id=c('k', 'dr'))
contribs$value = as.numeric(contribs$value)
ggplot(data=contribs, aes(x=k, y=(value/dr)/3, fill=variable)) + 
  geom_bar(stat='identity') +
  ggtitle('Contribution of each objective function to DFO for different values of k with 1600k reads') +
  ylab('proportional contribution of objective function')

library(lattice)
# surface plot with colour by DFO
plot((1-data$uts), data$rbas)
cloud(d ~ (1-uts)*rbas, data,
          xlab = "unexpressed transcripts", ylab = "annotated transcripts",
          main = "Optimisation surface",
          groups = d,
          colorkey = TRUE,
          screen = list(z = 60, x = -60)
)

# just some plots with fake data to see how we might plot our objective function results
require(SuppDists)

uts = rnorm(1300, 50, 20)/100.0
rbas = (rnorm(1300, 70, 5)/100.0)
brms = (rnorm(1300, 50, 20)/100.0)
fakedata <- data.frame(uts = uts,
                       rbas = rbas,
                       brms = brms)

dr <- function(opt, res, max) {
  return(((opt - res) / max) ** 2)
}

fakedata$dfo <- apply(fakedata, 1, function(x) {
  sqrt(dr(0, x[1], 1) +
  dr(1, x[2], 1) +
  dr(0, x[3], 1)) / 3
})

cloud(brms ~ uts*rbas, fakedata,
      xlab = "unexpressed transcripts", ylab = "annotated transcripts",
      zlab = "badly mapped reads",
      main = "Optimisation surface",
      screen = list(z =60, x = -60)
)