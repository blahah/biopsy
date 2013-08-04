opt_fake_run <- read.csv('fake_objective_opt.csv')
library(ggplot2)
data <- data.frame(iteration=1:800, score=opt_fake_run$score[1:800], hood_no=opt_fake_run$hood_no[1:800])
ggplot(data, aes(iteration, score, colour=hood_no)) +
  geom_point()