library(scatterplot3d)
# create column indicating point color
#merged_leaff_soapdt$pcolor = rainbow(length(merged_leaff_soapdt$L))[rank(merged_leaff_soapdt$L)]
merged_leaff_soapdt <- read.csv('outputdata/merged_leaff_soapdt.csv')
merged_leaff_soapdt <- merged_leaff_soapdt[-which(merged_leaff_soapdt$smallest == 0),]
# rainbow(length(merged_leaff_soapdt$X)) is not working, points arranged by order encountered not size
rainbow = rainbow(length(unique(merged_leaff_soapdt$K)))
names(rainbow) <- unique(merged_leaff_soapdt$K)
merged_leaff_soapdt$pcolor = apply(merged_leaff_soapdt, 1, function(x) rainbow[x[7]])
#merged_leaff_soapdt$pcolor = rainbow(length(merged_leaff_soapdt$L))
x <- merged_leaff_soapdt$numSeqs
y <- merged_leaff_soapdt$smallest
z <- merged_leaff_soapdt$n50
with(merged_leaff_soapdt, {
  s3d <- scatterplot3d(x, y, z,        # x y and z axis
                       pch=19, color=pcolor,
                       type="h", lty.hplot=2,       # lines to the horizontal plane
                       scale.y=.75,                 # scale y axis (reduce by 25%)
                       main="(numSeqs, smallest, n50) K",
                       xlab="numSeqs", 
                       ylab="smallest",
                       zlab="n50")
  s3d.coords <- s3d$xyz.convert(x, y, z)

})
# get some extra room
par(mar=c(7,4,4,6))
col.labels<-c(toString(min(merged_leaff_soapdt$K)),quantile(merged_leaff_soapdt$K, c(1, 3)/4), toString(max(merged_leaff_soapdt$K)))
# align labels below color bar?
color.legend(0,0,0,0,col.labels,merged_leaff_soapdt$pcolor,cex=1)