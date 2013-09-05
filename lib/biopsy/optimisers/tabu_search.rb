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
      @tabu << neighbour
      @members << neighbour
    end

    # update best?
    def update_best? current
      @best = current.clone if current[:score] > @best[:score]
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

    Thread = Struct.new(:best, :tabu, :distributions, 
                        :standard_deviations, :recent_scores, 
                        :iterations_since_best, :backtracks,
                        :current, :current_hood, :loaded)

    def initialize(parameter_ranges, threads=8, limit=nil)

      @ranges = parameter_ranges

      # solution tracking
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
      @hood_no = 1

      # adjustment tracking
      @recent_scores = []
      @jump_cutoff = 10

      # logging
      @log_data = false
      @logfiles = {}
      self.log_setup

      # backtracking
      @iterations_since_best = 0
      @backtrack_cutoff = 2
      @backtracks = 1.0

      # convergence
      @num_threads = 2
      @threads = []

    end # initialize

    def setup start_point
      @current = {:parameters => start_point, :score => nil}
      @best = @current
      self.setup_threads
    end

    # given the score for a parameter set,
    # return the next parameter set to be scored
    def run_one_iteration(parameters, score)
      @current = {:parameters => parameters, :score => score}
      # update best score?
      self.update_best?
      # log any data
      self.log
      # cycle threads
      self.load_next_thread
      # get next parameter set to score
      self.next_candidate
      @current[:parameters]
    end # run_one_iteration

    def setup_threads
      @num_threads.times do
        @threads << Thread.new
      end
      @threads.each do |thread|
        @current = {
          :parameters => self.random_start_point,
          :score => nil
        }
        @best = @current
        @standard_deviations = {}
        @recent_scores = []
        @tabu = Set.new
        self.define_neighbourhood_structure
        @current_hood = Biopsy::Hood.new(@distributions, @max_hood_size, @tabu)
        thread.members.each do |sym|
          ivar = self.sym_to_ivar_sym sym
          thread[sym] = self.instance_variable_get(ivar)
        end
        thread.loaded = false
      end
      @current_thread = @num_threads - 2
    end

    def load_next_thread
      thread = @threads[@current_thread]
      if thread.loaded
        thread.members.each do |sym|
          ivar = self.sym_to_ivar_sym sym
          thread[sym] = self.instance_variable_get(ivar)
        end
      else
        thread.loaded = true
      end
      @current_thread = (@current_thread + 1) % @num_threads
      thread = @threads[@current_thread]
      thread.members.each do |sym|
        ivar = self.sym_to_ivar_sym sym
        self.instance_variable_set(ivar, thread[sym])
      end
    end

    def update_best?
      @current_hood.update_best? @current
      if @best[:score].nil? || @current[:score] > @best[:score]
        @best = @current.clone
      else
        @iterations_since_best += 1
      end
    end

    # use probability distributions to define the
    # initial neighbourhood structure
    def define_neighbourhood_structure
      # probabilities
      @distributions = {}
      @current[:parameters].each_pair do |param, value|
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
      @current[:parameters] = @current_hood.next
      @current[:score] = nil
      # exhausted the neighbourhood?
      if @current_hood.last?
        # debug(@current_hood.best)
        self.next_hood
      end
    end

    # check termination conditions 
    # and return true if met
    def finished?
      return false if @threads.first.recent_scores.size < @jump_cutoff
      scores = @threads.map { |t| t.recent_scores }
      scores.map { |s| s.mean }.uniq.length == 1
    end

    # True if this algorithm chooses its own starting point
    def knows_starting_point?
      true
    end

    def log_setup
      if @log_data
        require 'csv'
        @logfiles[:standard_deviations] = CSV.open('standard_deviations.csv', 'w')
        @logfiles[:best] = CSV.open('best.csv', 'w')
        @logfiles[:score] = CSV.open('score.csv', 'w')
        @logfiles[:params] = CSV.open('params.csv', 'w')
      end
    end

    def log
      if @log_data
        @logfiles[:standard_deviations] << @distributions.map { |k, d| d.sd }
        @logfiles[:best] << [@best[:score]]
        @logfiles[:score] << [@current[:score]]
        @logfiles[:params] << @current[:parameters].map { |k, v| v }
      end
    end

    def log_teardown
      @logfiles.each_pair do |k, f|
        f.close
      end
    end

    def sym_to_ivar_sym sym
      "@#{sym.to_s}".to_sym
    end

    def select_starting_point
      self.random_start_point
    end

    def random_start_point
      Hash[@ranges.map { |p, r| [p, r.sample] }] 
    end

  end # TabuSearch

end # Biopsy