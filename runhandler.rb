# Optimisation Framework: Run Handler
#
# == Description
#
# The Run Handler is the main process controller for the entire optimisation
# cycle. It takes user input, runs the target program, the objective function(s)
# and the optimisation algorithm, looping through the optimisation cycle until
# completion and then returning the output.
#
module BiOpSy

  class RunHandler

	# Initialises the RunHandler
	# 
	# ==== Attributes
	# * +constructor+ - A Constructor object which takes as input
	#   a hash of parameter settings and returns a command that runs
	#   the target program with the settings (see Constructor documentation).
	# * +settings+ - Settings object containing the parameter ranges
	#   and the input settings and other metadata necessary to run 
	#   the experiment (see Settings documentation).
	#
	# ==== Options
	# * +:constructor+ - Constructor (see above)
	# * +:settings+ - Settings (see above)
	# * +:threads+ - Number of threads to use (as specified by user or default)
	# 
		def initialize(constructor, settings, optimiser=nil, threads=8)
			@constructor = constructor
			@settings = settings
			@optimiser = OptHandler.new(optimiser, threads)
			@objective = ObjectiveHandler.new(threads)
		end

		# Runs the experiment until the completion criteria
		# are met. On completion, returns the best parameter
		# set.
		def run
			in_progress = true
			@current_params = select_first_params
			while in_progress do
				run_iteration
				# update the best result
				@best = @optimiser.best
				# have we finished?
				in_progress = !@optimiser.finished?
			end
			return @best
		end

		# Runs a single iteration of the optimisation,
		# encompassing the program, objective(s) and optimiser.
		# Returns the output of the optimiser.
		def run_iteration
			# run the target
			run_data = @constructor.run @current_params
			# evaluate with objectives
			result = @objective.run run_data
			# get next steps from optimiser
			@current_params = @optimiser.run result
		end

		# Chooses the initial set(s) of parameters
		def select_first_params

		end

  end # end of class RunHandler

end # end of module BiOpSy