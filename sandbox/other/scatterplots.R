library(scatterplot3d)
# create column indicating point color
# rainbow(length(merged_leaff_soapdt$K))[rank(merged_leaff_soapdt$K)])
merged_leaff_soapdt$pcolor
merged_leaff_soapdt$pcolor[merged_leaff_soapdt$K>21] <- "red"
with(merged_leaff_soapdt, {
  s3d <- scatterplot3d(x, x, y,        # x y and z axis
                       pch=19, color=pcolor,        # circle color indicates no. of cylinders
                       type="h", lty.hplot=2,       # lines to the horizontal plane
                       scale.y=.75,                 # scale y axis (reduce by 25%)
                       main="3-D Scatterplot Example 4",
                       xlab="xlacement (cu. in.)",
                       ylab="Weight (lb/1000)",
                       zlab="Miles/(US) Gallon")
  s3d.coords <- s3d$xyz.convert(x, x, y)
  text(s3d.coords$x, s3d.coords$y,     # x and y coordinates
       labels=row.names(merged_leaff_soapdt),       # text to plot
       pos=4, cex=.5)                  # shrink text 50% and place to right of points)
  # add the legend
  legend("topleft", inset=.05,      # location and inset
         bty="n", cex=.5,              # suppress legend box, shrink text 50%
         title="Number of Cylinderssss",
         c("4", "6", "8"), fill=c("red", "blue", "darkgreen"))
})