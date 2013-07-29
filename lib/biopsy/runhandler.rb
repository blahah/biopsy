# Assembly Optimisation Framework: Run Handler
#
# == Description
#
# The Run Handler is the main process controller for the entire optimisation
# cycle. It takes user input, runs the target program, the objective function(s)
# and the optimisation algorithm, looping through the optimisation cycle until
# completion and then returning the output.
#
# == Explanation
#
# === Loading objective functions
#
# The Handler expects a directory containing objectives (by default it looks in *currentdir/objectives*).
# The *objectives* directory should contain the following:
#
# * a *.rb* file for each objective function. The file should define a subclass of ObjectiveFunction
# * (optionally) a file *objectives.txt* which lists the objective function files to use
#
# If the objectives.txt file is absent, the subset of objectives to use can be set directly in the Optimiser
# , or if no such restriction is set, the whole set of objectives will be run.
#
# Each file listed in *objectives.txt* is loaded if it exists.
#
# === Running objective functions
#
# The Handler iterates through the objectives, calling the *run()* method
# of each by passing the assembly. After collecting results, it returns
# a Hash of the results to the parent Optimiser.
module BiOpSy

  class RunHandler

	initialize(constructor, settings)
		@constructor = constructor
		@settings = settings
		
	end

  end # end of class ObjectiveHandler

end # end of module BiOpSy