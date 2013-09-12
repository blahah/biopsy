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

    attr_reader :inputs, :outputs, :retain_intermediates, :target, :start, :algorithm

    # Returns a new Experiment
    def initialize(target_name, start=nil, algorithm=nil)
      @start = start
      @algorithm = algorithm

      self.load_target target_name
      @objective = ObjectiveHandler.new @target
      self.select_algorithm
      self.select_starting_point
      @scores = {}
      @iteration_count = 0
    end

    # return the set of parameters to evaluate first
    def select_starting_point
      return unless @start.nil?
      if @algorithm && @algorithm.knows_starting_point?
        @start = @algorithm.select_starting_point
      else
        @start = self.random_start_point
      end
    end

    # Return a random set of parameters from the parameter space.
    def random_start_point
      Hash[@target.parameters.map { |p, r| [p, r.sample] }] 
    end

    # select the optimisation algorithm to use
    def select_algorithm
      max = Settings.instance.sweep_cutoff
      n = @target.count_parameter_permutations
      if n < max
        @algorithm = ParameterSweeper.new(@target.parameters)
      else
        @algorithm = TabuSearch.new(@target.parameters)
      end
    end

    # load the target named +:target_name+
    def load_target target_name
      @target = Target.new
      @target.load_by_name target_name
    end

    # Runs the experiment until the completion criteria
    # are met. On completion, returns the best parameter
    # set.
    def run
      in_progress = true
      @algorithm.setup @start
      @current_params = @start
      while in_progress do
        run_iteration
        # update the best result
        @best = @algorithm.best
        # have we finished?
        in_progress = !@algorithm.finished?
      end
      puts "found optimum score: #{@best[:score]} for parameters #{@best[:parameters]} in #{@iteration_count} iterations."
      return @best
    end

    # Runs a single iteration of the optimisation,
    # encompassing the program, objective(s) and optimiser.
    # Returns the output of the optimiser.
    def run_iteration
      # create temp dir
        Dir.chdir(self.create_tempdir) do
        # run the target
        raw_output = @target.run @current_params
        # evaluate with objectives
        param_key = @current_params.to_s
        result = nil
        if @scores.has_key? param_key
          result = @scores[param_key]
        else
          result = @objective.run_for_output raw_output
          @iteration_count += 1
        end
        @scores[@current_params.to_s] = result
        # get next steps from optimiser
        @current_params = @algorithm.run_one_iteration(@current_params, result)
      end
      self.cleanup
    end

    def cleanup
      # TODO: make this work
      # remove all but essential files
      if Settings.instance.keep_intermediates
        @objectives.values.each{ |objective| essential_files += objective.essential_files }
      end
      Dir["*"].each do |file|
        next if File.directory? file
        if essential_files && essential_files.include?(file)
          `gzip #{file}` if Settings.instance.gzip_intermediates
          FileUtils.mv("#{file}.gz", '../output')
        end
      end
      FileUtils.rm_rf @last_tempdir
    end

    # create a guaranteed random temporary directory for storing outputs
    # return the dirname
    def create_tempdir
      token = loop do
        # generate random dirnames until we find one that
        # doesn't exist
        test_token = SecureRandom.hex
        break test_token unless File.exists? test_token
      end
      Dir.mkdir(token)
      @last_tempdir = token
      return token
    end

  end # end of class RunHandler

end # end of module Biopsy