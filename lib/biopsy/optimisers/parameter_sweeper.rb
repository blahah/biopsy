# ParameterSweeper.new(options, constructor)
# options = {:settings => {...}, :parameters => {...}}
#
# Description:
# ParameterSweeper generates all combinations of a hash of arrays
# (options[:parameters]).
# The generated combinations are each passed in turn to the constructor
# which returns an execute command incorporating the parameters, and finally
# the target program is run with each generated command.
#
# The constructor will also have access to an unchanging settings hash
# (options[:settings]) constructor proc will be passed multipule hashes in
# format: {:settings => {...}, :parameters => {...}} where the values in
# settings remain constant, and the values in parameters vary

require 'pp'
require 'fileutils'
require 'csv'
require 'threach'
require 'logger'

module Biopsy

  class Combinator

    include Enumerable
   
    def initialize parameters
      @parameters = parameters
    end
   
    def generate_combinations(index, opts, &block)
      if index == @parameters.length
        block.call opts.clone
        return
      end
      # recurse
      key = @parameters.keys[index]
      @parameters[key].each do |value|
        opts[key] = value
        generate_combinations(index + 1, opts, &block)
      end
    end

    def each &block
      generate_combinations(0, {}, &block)
    end
  end

  # options - is a hash of two hashes, :settings and :parameters
  #   :ranges are arrays to be parameter sweeped
  #     ---(single values may be present, these are also remain unchanged
  #     but are accessible within the parameters hash to the constructor)
  class ParameterSweeper

    attr_reader :combinator, :combinations, :best

    def initialize(ranges)
      @ranges = ranges
      # convert all options to an array so it can be handled by the
      # generate_combinations() method
      # ..this is for users entering single values e.g 4 as a parameter
      @ranges.each_value{ |value| value = [value] unless value.kind_of? Array }
      # restrict to a subsample?
      @combinations = 1
      @ranges.each { |r| @combinations *= r[1].size }
      @is_finished = false
      @combinator = (Combinator.new @ranges).to_enum
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
      return @combinator.next
    rescue 
      @is_finished = true
      return nil
    end

    def update_best?
      raise "best is nil. should run setup first" if @best.nil?
      if @best[:score].nil? || @current[:score] > @best[:score]
        @best = @current.clone
      end
    end

    def next
      @combinator.next
    rescue
      nil
    end

    def knows_starting_point?
      true
    end

    def select_starting_point
      @combinator.next
    end

    def random_start_point
      @combinator.next
    end

    def finished?
      @is_finished
    end

    # True if this algorithm chooses its own starting point
    def knows_starting_point?
      true
    end
  end
end
