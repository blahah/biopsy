require 'rubystats'
require 'statsample'
require 'set'
require 'pp'
require 'matrix'

# TODO:
# - make distributions draw elements from the range, not just from distribution (DONE)
# - test on real SOAPdt data (in progress)
# - make code to run 100 times for a particular dataset, capture the trajectory, and plot the progress over time along with a histogram of the data distribution
# - plot SD and step-size over time
# - capture data about convergence (done for toy data, need to repeat for other data)

module Biopsy

  # a Distribution represents the probability distribution from
  # which the next value of a parameter is drawn. The set of all
  # distributions acts as a probabilistic neighbourhood structure.
  class Distribution

    attr_reader :sd

    # create a new Distribution
    def initialize(mean, range, sd_increment_proportion, sd)
      @mean = mean
      @maxsd = range.size * 0.66
      @minsd = 0.5
      @sd = sd
      self.limit_sd
      @range = range
      @sd_increment_proportion = sd_increment_proportion
      self.generate_distribution
    rescue
        raise "generation of distribution with mean: #{@mean}, sd: #{@sd} failed."
    end

    # generate the distribution
    def generate_distribution
      @dist = Rubystats::NormalDistribution.new(@mean, @sd)
    end

    def limit_sd
      @sd = @sd > @maxsd ? @maxsd : @sd
      @sd = @sd < @minsd ? @minsd : @sd
    end

    # loosen the distribution by increasing the sd
    # and renerating
    def loosen(factor=1)
      @sd += @sd_increment_proportion * factor * @range.size
      self.limit_sd
      self.generate_distribution
    end

    # tighten the distribution by reducing the sd
    # and regenerating
    def tighten(factor=1)
      @sd -= @sd_increment_proportion * factor * @range.size unless (@sd <= 0.01)
      self.limit_sd
      self.generate_distribution
    end

    # set standard deviation to the minimum possible value
    def set_sd_min
      @sd = @minsd
    end

    # draw from the distribution
    def draw
      r = @dist.rng.to_i
      raise "drawn number must be an integer" unless r.is_a? Integer
      # keep the value inside the allowed range
      r = 0 - r if r < 0
      if r >= @range.size
        diff = 1 + r - @range.size
        r = @range.size - diff
      end
      @range[r]
    end

  end # Distribution

  # a Hood represents the neighbourhood of a specific location
  # in the parameter space being explored. It is generated using
  # the set of Distributions, which together define the neighbourhood
  # structure.
  class Hood

    attr_reader :best

    def initialize(distributions, max_size, tabu)
      # tabu
      @tabu = tabu 
      # neighbourhood
      @max_size = max_size
      @members = []
      @best = {
        :parameters => nil,
        :score => 0.0
      }
      # probabilities
      @distributions = distributions
      self.populate
    end

    # generate a single neighbour
    def generate_neighbour
      n = 0
      begin
        if n >= 100
          # taking too long to generate a neighbour, 
          # loosen the neighbourhood structure so we explore further
          # debug("loosening distributions")
          @distributions.each do |param, dist|
            dist.loosen
          end
        end
        # preform the probabilistic step move for each parameter
        neighbour = Hash[@distributions.map { |param, dist| [param, dist.draw] }]
        n += 1
      end while self.is_tabu?(neighbour)
      @members << neighbour
    end

    # update best?
    def update_best? current
      @best = current if current[:score] > @best[:score]
    end

    # true if location is tabu
    def is_tabu? location
      @tabu.member? location
    end

    # generate the population of neighbours
    def populate
      @max_size.times do |i|
        self.generate_neighbour
      end
    end

    # return the next neighbour from this Hood
    def next
      @members.pop
    end

    # returns true if the current neighbour is
    # the last one in the Hood
    def last?
      @members.empty?
    end

  end # Hood

  # A Tabu Search implementation with a domain-specific probabilistic
  # learning heuristic for optimising over an unconstrained parameter
  # space with costly objective evaluation.
  class TabuSearch #< OptmisationAlgorithm

    attr_reader :current, :best, :hood_no
    attr_accessor :max_hood_size, :sd_increment_proportion, :starting_sd_divisor, :backtrack_cutoff
    attr_accessor :jump_cutoff

    def initialize(parameter_ranges, threads=8, limit=nil)

      @ranges = parameter_ranges

      # solution tracking
      @current = Hash[parameter_ranges.map { |param, range| [param, range.sample] }]
      @best = nil

      # tabu list
      @tabu = Set.new
      @tabu_limit = nil
      @start_time = Time.now

      # neighbourhoods
      @max_hood_size = 5
      @starting_sd_divisor = 5
      @standard_deviations = {}
      @sd_increment_proportion = 0.05
      self.define_neighbourhood_structure
      @current_hood = Biopsy::Hood.new(@distributions, @max_hood_size, @tabu)
      @hood_no = 1

      # adjustment tracking
      @recent_scores = []
      @jump_cutoff = 10

      # backtracking
      @iterations_since_best = 0
      @backtrack_cutoff = 2
      @backtracks = 1.0

    end # initialize

    # given the score for a parameter set,
    # return the next parameter set to be scored
    def run_one_iteration(parameters, score)
      @current = {:parameters => parameters, :score => score}
      # update best score?
      self.update_best? @current
      # get next parameter set to score
      self.next_candidate
      # update tabu list
      self.update_tabu
      @current
    end # run_one_iteration

    def update_best? current
      @current_hood.update_best? current
      if @best.nil? || @current[:score] > @best[:score]
        @best = @current
      else
        @iterations_since_best += 1
      end
    end

    # use probability distributions to define the
    # initial neighbourhood structure
    def define_neighbourhood_structure
      # probabilities
      @distributions = {}
      @current.each_pair do |param, value|
        self.update_distribution(param, value)
      end
    end

    # update the neighbourhood structure by adjusting the probability
    # distributions according to total performance of each parameter
    def update_neighbourhood_structure
      self.update_recent_scores
      best = self.backtrack_or_continue
      unless @distributions.empty?
        @standard_deviations = Hash[@distributions.map { |k, d| [k, d.sd] }]
      end
      best[:parameters].each_pair do |param, value|
        self.update_distribution(param, value)
      end
    end

    # set the distribution for parameter +:param+ to a new one centered
    # around the index of +value+
    def update_distribution(param, value)
      mean = @ranges[param].index(value)
      range = @ranges[param]
      sd = self.sd_for_param(param, range)
      @distributions[param] = Biopsy::Distribution.new(mean, 
                                                      range,
                                                      @sd_increment_proportion,
                                                      sd)
    end

    # return the standard deviation to use for +:param+
    def sd_for_param(param, range)
      @standard_deviations.empty? ? (range.size.to_f / @starting_sd_divisor) : @standard_deviations[param]
    end

    # return the correct 'best' location to form a new neighbourhood around
    # deciding whether to continue progressing from the current location
    # or to backtrack to a previous good location to explore further
    def backtrack_or_continue
      best = nil
      if (@iterations_since_best / @backtracks) >= @backtrack_cutoff * @max_hood_size
        self.backtrack
        best = @best
      else
        best = @current_hood.best
        self.adjust_distributions_using_gradient
      end
      if best[:parameters].nil?
        # this should never happen!
        best = @best        
      end
      best
    end

    def backtrack
      @backtracks += 1.0
      # debug('backtracked to best')
      @distributions.each_pair { |k, d| d.tighten }
    end

    # update the array of recent scores
    def update_recent_scores
      @recent_scores.unshift @best[:score]
      @recent_scores = @recent_scores.take @jump_cutoff
    end

    # use the gradient of recent best scores to update the distributions
    def adjust_distributions_using_gradient
      return if @recent_scores.length < 3
      vx = (1..@recent_scores.length).to_a.to_scale
      vy = @recent_scores.reverse.to_scale
      r = Statsample::Regression::Simple.new_from_vectors(vx,vy)
      slope = r.b
      if slope > 0
        @distributions.each_pair { |k, d| d.tighten slope }
      elsif slope < 0
        @distributions.each_pair { |k, d| d.loosen slope }
      end
    end

    # shift to the next neighbourhood
    def next_hood
      @hood_no += 1
      # debug("entering hood # #{@hood_no}")
      self.update_neighbourhood_structure
      @current_hood = Hood.new(@distributions, @max_hood_size, @tabu)
    end

    # get the next neighbour to explore from the current hood
    def next_candidate
      @current = @current_hood.next
      # exhausted the neighbourhood?
      if @current_hood.last?
        # debug(@current_hood.best)
        self.next_hood
      end
    end

    # update the tabu list, performing any necessary manupulations
    # such as removing the oldest entires if there is a size limit
    def update_tabu
       @tabu << @current
    end

    # check termination conditions 
    # and return true if met
    def finished?
      if @iterations_since_best >= 100
        puts "iterations: #{@tabu.size}"
        puts "backtracks: #{@backtracks}"
        pp @standard_deviations
      end
      @iterations_since_best >= 100
    end

    # True if this algorithm chooses its own starting point
    def knows_starting_point?
      false
    end

  end # TabuSearch

end # Biopsy