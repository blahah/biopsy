require 'securerandom'
require 'fileutils'

# Assembly Optimisation Framework: Objective Function Handler
#
# == Description
#
# The Handler manages the objective functions for the optimisation experiment.
# Specifically, it finds all the objective functions and runs them when 
# requested, outputting the results to the main Optimiser.
#
# == Explanation
#
# === Loading objective functions
#
# The Handler expects a directory containing objectives (by default it looks
# in *currentdir/objectives*).
# The *objectives* directory should contain the following:
#
# * a *.rb* file for each objective function. The file should define a subclass
#     of ObjectiveFunction
# * (optionally) a file *objectives.txt* which lists the objective function
#     files to use
#
# If the objectives.txt file is absent, the subset of objectives to use can be
# set directly in the Optimiser, or if no such restriction is set, the whole
# set of objectives will be run.
#
# Each file listed in *objectives.txt* is loaded if it exists.
#
# === Running objective functions
#
# The Handler iterates through the objectives, calling the *run()* method
# of each by passing the assembly. After collecting results, it returns
# a Hash of the results to the parent Optimiser.
module Biopsy

  class ObjectiveHandlerError < Exception
  end

  class ObjectiveHandler

    attr_reader :last_tempdir
    attr_accessor :objectives

    def initialize(target)
      @target = target
      @objectives_dir = Settings.instance.objectives_dir.first
      @objectives = {}
      $LOAD_PATH.unshift(@objectives_dir)
      if Settings.instance.respond_to?(:objectives_subset)
        @subset = Settings.instance.objectives_subset
      else
        @subset = nil
      end
      load_objectives
      # pass objective list back to caller
      @objectives.keys
    end

    def load_objectives
      # load objectives
      # load subset list if available
      subset_file = @objectives_dir + '/objectives.txt'
      if File.exist?(subset_file)
        subset = File.open(subset_file).readlines.map { |l| l.strip }
      else
        subset = nil
      end
      subset = @subset if subset.nil?
      # parse in objectives
      Dir.chdir @objectives_dir do
        Dir['*.rb'].each do |f|
          file_name = File.basename(f, '.rb')
          require file_name
          objective_name = file_name.camelize
          objective =  Module.const_get(objective_name).new
          if subset.nil? || subset.include?(file_name)
            # this objective is included
            @objectives[objective_name] = objective
          end
        end
        # puts "loaded #{@objectives.length} objectives."
      end
    end

    # Run a specific +:objective+ on the +:output+ of a target
    # with max +:threads+.
    def run_objective(objective, _name, raw_output, output_files, threads)
      # output is a, array: [raw_output, output_files].
      # output_files is a hash containing the absolute paths
      # to file(s) output by the target in the format expected by the
      # objective function(s), with keys as the keys expected by the
      # objective function
      return objective.run(raw_output, output_files, threads)
    end

    # Perform a euclidean distance dimension reduction of multiple objectives
    def dimension_reduce(results)
      # calculate the weighted Euclidean distance from optimal
      # d(p, q) = \sqrt{(p_1 - q_1)^2 + (p_2 - q_2)^2+...+(p_n - q_n)^2}
      # here the max value is sqrt(n) where n is no. of results,
      #   min value (optimum) is 0
      total = 0
      results.each_value do |value|
        o = value[:optimum]
        w = value[:weighting]
        a = value[:result]
        m = value[:max]
        total += w * (((o - a) / m)**2) if m != 0
      end
      Math.sqrt(total) / results.length
    end

    # Run all objectives functions for +:output+.
    def run_for_output(raw_output, threads, allresults)
      # check output files exist
      output_files = {}
      @target.output.each_pair do |key, glob|
        files = Dir[glob]
        size = files.reduce(1) { |sum, f| sum * File.size(f)}
        if files.empty? || size==0
          error = "output files for #{key} matching #{glob} do not exist" +
                  " or are empty"
          raise ObjectiveHandlerError, error
        end
        output_files[key] = files.map { |f| File.expand_path(f) }
      end

      # run all objectives for output
      results = {}
      @objectives.each_pair do |name, objective|
        results[name] = self.run_objective(objective, name, raw_output,
                                           output_files, threads)
      end

      if allresults
        return { :results => results,
                 :reduced => self.dimension_reduce(results) }
      else
        results.each_value do |value|
          return value.kind_of?(Hash) ? value[:result] : value
        end
      end
    end
  end
end
