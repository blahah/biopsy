# Optimisation Framework: Optimisation Algorithm Handler
#
# == Description
#
# The Handler manages the optimisation algorithms for the optimisation experiment.
# Specifically, it finds all the available algorithms and runs then when requested.
#
# The handler takes parameter space as initial input and objective function scores 
# as continuous input.
#
# Each iteration results in the next set(s) of parameters to use being output, and
# when the run is complete, the optimal set of parameters is returned.
#
# == Explanation
#
# === Loading optimisation algorithms
#
# The Handler expects a directory containing optimisation algorithms
# (by default it looks in *currentdir/optimisers*).
# The *optimisers* directory should contain the following:
#
# * a *.rb* file for each optimisation algorithm. The file should define a subclass of OptAlgorithm
#
# Which algorith will be executed is decided based on user input or on the data.
#
module BiOpSy

  class ObjectiveHandler

  end # end of class ObjectiveHandler

end # end of module BiOpSy