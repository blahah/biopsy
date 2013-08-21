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

    def initialize(ranges, threads=8, limit=nil)
      @ranges = ranges
      # parameter_counter: a count of input parameters to be used
      @parameter_counter = 1
      # input_combinations: an array of arrays of input parameters
      @combinations = []
      # if the number of threads is set, update the global variable, if not default to 1
      @threads = threads
      # convert all options to an array so it can be handled by the generate_combinations() method
      # ..this is for users entering single values e.g 4 as a parameter
      @ranges.each { |key, value| value = [value] unless value.kind_of? Array }
      self.generate_combinations
      # restrict to a subsample?
      unless limit.nil?
        @combinations = @combinations.sample limit
      end
    end

    # return the next parameter set to evaluate
    def run_one_iteration(*args)
      @combinations.pop
    rescue
      nil
    end

    # generate all the parameter combinations to be applied
    def generate_combinations(index=0, opts={})
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
  end
end