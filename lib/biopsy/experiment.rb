# Optimisation Framework: Experiment
#
# == Description
#
# The Experiment object encapsulates the data and methods that represent
# the optimisation experiment being carried out.
#
# The metadata necessary to conduct the experiment, as well as the
# settings for the experiment, are stored here.
#
# It is also the main process controller for the entire optimisation
# cycle. It takes user input, runs the target program, the objective function(s)
# and the optimisation algorithm, looping through the optimisation cycle until
# completion and then returning the output.
module Biopsy

  class Experiment

    attr_reader :inputs, :outputs, :retain_intermediates, :target

    # Initialises the Experiment
    #
    # ==== Attributes
    # * +inputs+ a Hash mapping input types to filenames. Inputs will be passed to the target for execution with each run.
    # * +outputs+ a Hash mapping output types to filenames. Outputs will be passed to objective fucntions.
    # * +retain_intermediates+ a boolean indicating whether files other than the outputs should be retained during the experiment. The output files are those specified by each objective function.
    # * +target+ Target object describing constructor and parameter ranges for the target program.
    # * +best_parameters+ the set of best scoring parameters tested
    # * +best_score+ the best score achieved during the experiment
    #
    # ==== Options
    # * +:inputs+ see above
    # * +:outputs+ see above
    # * +:retain_intermediates+ see above
    # * +:target+ see above
    # * +:domain+ a Domain object representing the kind of optimisation experiment being performed
    def initialize(domain)
      @domain = domain

      self.load_target
      self.select_algorithm
      self.select_starting_point
    end

    # return the set of parameters to evaluate first
    def select_starting_point

    end

    # select the optimisation algorithm to use
    def select_algorithm

    end

    # load the parameter ranges and constructor for the target
    def load_target
      # @ranges = @domain.get_ranges target
      # @constructor = @domain.get_constructor target
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

  end # end of class RunHandler

end # end of module Biopsy