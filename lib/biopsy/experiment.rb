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
require 'logger'

module Biopsy

  class Experiment

    attr_reader :inputs, :outputs, :retain_intermediates
    attr_reader :target, :start, :algorithm

    # Returns a new Experiment
    def initialize(target, options:{}, threads:4, start:nil, algorithm:nil,
                   timelimit:nil, verbosity: :quiet, id:nil)
      @threads = threads
      @start = start
      @algorithm = algorithm
      @timelimit = timelimit
      @verbosity = verbosity
      if target.is_a? Target
        @target = target
      else
        self.load_target target
      end
      @options = options
      @objective = ObjectiveHandler.new @target
      self.select_algorithm
      self.select_starting_point
      @scores = {}
      @iteration_count = 0
      set_id id
    end

    # return the set of parameters to evaluate first
    def select_starting_point
      return if !@start.nil?
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
      return if algorithm
      max = Settings.instance.sweep_cutoff
      n = @target.count_parameter_permutations
      if n < max
        @algorithm = ParameterSweeper.new(@target.parameters, @id)
      else
        @algorithm = TabuSearch.new(@target.parameters, @id)
      end
    end

    # load the target named +:target_name+
    def load_target(target_name)
      @target = Target.new
      @target.load_by_name target_name
    end

    # Runs the experiment until the completion criteria
    # are met. On completion, returns the best parameter
    # set.
    def run
      start_time = Time.now
      in_progress = true
      @algorithm.setup @start
      @current_params = @start
      max_scores = @target.count_parameter_permutations
      while in_progress
        run_iteration
        # update the best result
        best = @best
        @best = @algorithm.best
        ptext = @best[:parameters].each_pair.map{ |k, v| "#{k}:#{v}" }.join(", ")
        if @best &&
           @best.key?(:score) &&
           best &&
           best.key?(:score) &&
           @best[:score] > best[:score]
           unless @verbosity == :silent
             puts "found a new best score: #{@best[:score]} "+
                  "for parameters #{ptext}"
           end
        end
        # have we finished?
        in_progress = !@algorithm.finished? && @scores.size < max_scores
        if in_progress && !(@timelimit.nil?)
          in_progress = (Time.now - start_time < @timelimit)
        end
      end
      @algorithm.write_data if @algorithm.respond_to? :write_data
      unless @verbosity == :silent
        puts "found optimum score: #{@best[:score]} for parameters "+
             "#{@best[:parameters]} in #{@iteration_count} iterations."
      end
      return @best
    end

    # Runs a single iteration of the optimisation,
    # encompassing the program, objective(s) and optimiser.
    # Returns the output of the optimiser.
    def run_iteration
      param_key = @current_params.to_s
      result = nil
      # lookup the result if possible
      if @scores.key? param_key
        result = @scores[param_key]
      else
        # create temp dir
        curdir = Dir.pwd
        Dir.chdir(self.create_tempdir) unless Settings.instance.no_tempdirs
        # run the target
        raw_output = @target.run @current_params.merge(@options)
        # evaluate with objectives
        result = @objective.run_for_output(raw_output, @threads, nil)
        @iteration_count += 1
        self.print_progress(@iteration_count, @current_params, result, @best)
        @scores[@current_params.to_s] = result
        self.cleanup
        Dir.chdir(curdir) unless Settings.instance.no_tempdirs
      end
      # get next steps from optimiser
      @current_params = @algorithm.run_one_iteration(@current_params, result)
    end

    def print_progress(iteration, params, score, best)
      unless [:silent, :quiet].include? @verbosity
        ptext = params.each_pair.map{ |k, v| "#{k}:#{v}" }.join(", ")
        msg = "run #{iteration}. parameters: #{ptext} | score: #{score}"
        msg += " | best #{best[:score]}" if (best && best.has_key?(:score))
        puts msg
      end
    end

    def cleanup
      return if Settings.instance.no_tempdirs
      # TODO: make this work
      # remove all but essential files
      essential_files = ""
      if Settings.instance.keep_intermediates
        # @objectives isn't mentioned anywhere in the rest of this file
        @objectives.values.each do |objective|
          essential_files += objective.essential_files
        end
      end
      Dir["*"].each do |file|
        next
        # TODO: implement this
        # next if File.directory? file
        # if essential_files && essential_files.include?(file)
        #   `gzip #{file}` if Settings.instance.gzip_intermediates
        #   FileUtils.mv("#{file}.gz", '../output')
        # end
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
        break test_token unless File.exist? test_token
      end
      Dir.mkdir(token)
      @last_tempdir = token
      token
    end

    # set experiment ID with either user provided value, or date-time
    # as fallback
    def set_id id
      @id = id
      if @id.nil?
        t = Time.now
        parts = %w[y m d H M S Z].map{ |p| t.strftime "%#{p}" }
        @id = "experiment_#{parts.join('_')}"
      end
    end

  end # end of class RunHandler

end # end of module Biopsy
