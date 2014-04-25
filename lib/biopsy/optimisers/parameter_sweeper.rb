# ParameterSweeper.new(options, constructor)
# options = {:settings => {...}, :parameters => {...}}
#
# Description:
# ParameterSweeper generates all combinations of a hash of arrays (options[:parameters]).
# The generated combinations are each   passed in turn to the constructor which returns an execute command
# incorporating the parameters, and finally the target program is run with each generated command.
#
# The constructor will also have access to an unchanging settings hash (options[:settings])
# constructor proc will be passed multipule hashes in format: {:settings => {...}, :parameters => {...}}
# where the values in settings remain constant, and the values in parameters vary 

require 'pp'
require 'fileutils'
require 'csv'
require 'threach'
require 'logger'

module Biopsy
  # options - is a hash of two hashes, :settings and :parameters
  #   :ranges are arrays to be parameter sweeped
  #     ---(single values may be present, these are also remain unchanged but are accessible within the parameters hash to the constructor)
  class ParameterSweeper

    attr_reader :combinations

    def initialize(ranges, threads:1, limit:1000)
      @ranges = ranges
      # parameter_counter: a count of input parameters to be used
      @parameter_counter = 1
      # input_combinations: an array of arrays of input parameters
      @combinations = []
      # if the number of threads is set, update the global variable, if not default to 1
      @threads = threads
      # set the limit to the number of parameters
      @limit = limit
      # convert all options to an array so it can be handled by the generate_combinations() method
      # ..this is for users entering single values e.g 4 as a parameter
      @ranges.each { |key, value| value = [value] unless value.kind_of? Array }
      self.generate_combinations(0, {})
      # restrict to a subsample?
      
      if @limit < @combinations.size
        @combinations = @combinations.sample @limit
      end
    end

    def setup(*_args)
      @best = {
        :parameters => nil,
        :score => nil
      }
    end

    # return the next parameter set to evaluate
    def run_one_iteration(parameters, score)
      @current = { :parameters => parameters, :score => score }
      self.update_best?
      @combinations.pop
    rescue
      nil
    end

    def update_best?
      if @best[:score].nil? || @current[:score] > @best[:score]
        @best = @current.clone
      end
    end

    # generate all the parameter combinations to be applied
    def generate_combinations(index, opts)
      if index == @ranges.length
        @combinations << opts.clone
        return
      end
      # recurse
      key = @ranges.keys[index]
      @ranges[key].each do |value|
        opts[key] = value
        generate_combinations(index + 1, opts)
      end
    end

    def best
      @best
    end

    def knows_starting_point?
      true
    end

    def select_starting_point
      @combinations.pop
    end

    def random_start_point
      @combinations.pop
    end

    def finished?
      @combinations.empty?
    end

    # True if this algorithm chooses its own starting point
    def knows_starting_point?
      true
    end
  end
end