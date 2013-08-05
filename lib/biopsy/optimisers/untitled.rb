require 'gsl'

r = GSL::Rng.alloc
p r.cauchy(5, 10)
p r.cauchy(5, 5)
p r.cauchy(10, 5)