require 'securerandom'
require 'fileutils'

# extend String to implement camelize from Rails
class String
  def camelize
    return self if self !~ /_/ && self =~ /[A-Z]+.*/
    split('_').map{|e| e.capitalize}.join
  end
end

# Assembly Optimisation Framework: Objective Function Handler
#
# == Description
#
# The Handler manages the objective functions for the optimisation experiment.
# Specifically, it finds all the objective functions and runs them when requested,
# outputting the results to the main Optimiser.
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
  class ObjectiveHandler

    attr_reader :last_tempdir

    def initialize(objectives_dir='objectives', subset=nil)
      base_dir = File.expand_path(File.dirname(__FILE__))
      $LOAD_PATH.unshift(base_dir)
      @objectives_dir = File.join(base_dir, objectives_dir)
      @objectives = {}
      @subset = subset
      self.load_objectives
      # pass objective list back to caller
      return @objectives.keys
    end

    def load_objectives
      # load objectives
      # load subset list if available
      subset_file = @objectives_dir+'/objectives.txt'
      subset = File.exists?(subset_file) ? File.open(subset_file).readlines : nil
      subset = @subset if subset.nil?
      # parse in objectives
      Dir.chdir @objectives_dir do
        Dir['*.rb'].each do |file|
          require_relative @objectives_dir + '/' + file
          file_name = File.basename(file, '.rb')
          objective_name = file_name.camelize
          objective =  Module.const_get(objective_name).new
          if subset.nil? or subset.includes?(file_name)
            # this objective is included
            @objectives[objective_name] = objective
          end
        end
        puts "loaded #{@objectives.length} objectives."
      end
    end

    def run_objective(objective, name, assembly, threads)
      # run objective for assembly
      begin
        # assembly is a hash containing:
        # - :assembly (path to assembly .fasta)
        # - :leftreads (path to assembly left reads)
        # - :rightreads (path to assembly right reads)
        return objective.run(assembly, threads)
      rescue NotImplementedError => e
        puts "Error: objective function #{name} does not implement the run() method"
        puts "Please refer to the documentation for instructions on adding objective functions"
        raise e
      end
    end

    def dimension_reduce(results)
      # calculate the weighted Euclidean distance from optimal
      #d(p, q) = \sqrt{(p_1 - q_1)^2 + (p_2 - q_2)^2+...+(p_i - q_i)^2+...+(p_n - q_n)^2}
      # here the max value is sqrt(n) where n is no. of results, min value (optimum) is 0
      total = 0
      results.each_pair do |key, value|
        o = value[:optimum]
        w = value[:weighting]
        a = value[:result]
        m = value[:max]
        total += w * (((o - a)/m) ** 2)
      end
      return Math.sqrt(total) / results.length
    end

    def run_for_assembly(assembly, threads=24, cleanup=true,allresults=false)
      # check assembly exists
      unless File.exists?(assembly[:assembly]) && `wc -l #{assembly[:assembly]}`.to_i > 0
        return nil
      end
      # run all objectives for assembly
      results = {}
      # create temp dir
      Dir.chdir(self.create_tempdir) do
        @objectives.each_pair do |name, objective|
          results[name] = self.run_objective(objective, name, assembly, threads)
        end
      end
      # remove temp dir?
      FileUtils.rm_rf @last_tempdir if cleanup
      if allresults
        return {:results => results,
                :reduced => self.dimension_reduce(results)}
      else
        return self.dimension_reduce(results)
      end
    end

    def create_tempdir
      # create a guaranteed random temporary directory for storing outputs
      # return the dirname
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

  end
end
