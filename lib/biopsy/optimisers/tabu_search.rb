require 'rubystats'
require 'methadone'
require 'set'
require 'pp'

# TODO:
# - make distributions draw elements from the range, not just from distribution (DONE)
# - test on real SOAPdt data (in progress)
# - make code to run 100 times for a particular dataset, capture the trajectory, and plot the progress over time along with a histogram of the data distribution
# - plot SD and step-size over time
# - capture data about convergence (done for toy data, need to repeat for other data)

module BiOpSy

  # a Distribution represents the probability distribution from
  # which the next value of a parameter is drawn. The set of all
  # distributions acts as a probabilistic neighbourhood structure.
  class Distribution

    include Methadone::CLILogging

    # create a new Distribution
    def initialize(mean, range, sd_increment_proportion, starting_sd_divisor)
      @mean = mean
      @sd = range.size.to_f / starting_sd_divisor # this is arbitrary - should we learn a good initial setting?
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

    # loosen the distribution by increasing the sd
    # and renerating
    def loosen
      @sd += @sd_increment_proportion * @range.size
      self.generate_distribution
    end

    # tighten the distribution by reducing the sd
    # and regenerating
    def tighten
      @sd -= @sd_increment_proportion * @range.size unless (@sd <= 0.5)
      self.generate_distribution
    end

    # draw from the distribution
    def draw
      r = @dist.rng.to_i
      # keep the value inside the allowed range
      r = @range.size - r if r >= @range.size
      r = 0 - r if r < 0
      # discretise
      @range.each_with_index do |v, i|
        if i >= r
          return v
        end
      end
    end

  end # Distribution

  # a Hood represents the neighbourhood of a specific location
  # in the parameter space being explored. It is generated using
  # the set of Distributions, which together define the neighbourhood
  # structure.
  class Hood

    include Methadone::CLILogging

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
        if n >= 10
          # taking too long to generate a neighbour, 
          # loosen the neighbourhood structure so we explore further
          debug("loosening distributions")
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

    include Methadone::CLILogging

    attr_reader :current, :best, :hood_no
    attr_writer :max_hood_size, :sd_increment_proportion, :starting_sd_divisor, :backtrack_cutoff

    def initialize(parameter_ranges, threads=8, limit=nil)

      @ranges = parameter_ranges

      # solution tracking
      @current = Hash[parameter_ranges.map { |param, range| [param, range.sample] }]
      @best = {:score => 0}

      # tabu list
      @tabu = Set.new
      @tabu_limit = nil
      @start_time = Time.now

      # neighbourhoods
      @max_hood_size = 50
      @starting_sd_divisor = 30
      @sd_increment_proportion = 0.1
      self.define_neighbourhood_structure
      @current_hood = BiOpSy::Hood.new(@distributions, @max_hood_size, @tabu)
      @hood_no = 1

      # backtracking
      @iterations_since_best = 0
      @backtrack_cutoff = 3

    end # initialize

    # if not being controlled by RunController, #run
    # will conduct the optimisation experiment.
    # intended only for internal testing use
    def run
      nil
    end # run

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
      if @current[:score] > @best[:score]
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
        mean = @ranges[param].index(value)
        range = @ranges[param]
        @distributions[param] = BiOpSy::Distribution.new(mean, 
                                                        range,
                                                        @sd_increment_proportion,
                                                        @starting_sd_divisor)
      end
    end

    # update the neighbourhood structure by adjusting the probability
    # distributions according to total performance of each parameter
    def update_neighbourhood_structure
      self.backtrack_or_continue()[:parameters].each_pair do |param, value|
        mean = @ranges[param].index(value)
        range = @ranges[param]
        @distributions[param] = BiOpSy::Distribution.new(mean, 
                                                        range,
                                                        @sd_increment_proportion,
                                                        @starting_sd_divisor)
      end
    end

    # return the correct 'best' location to form a new neighbourhood around
    # deciding whether to continue progressing from the current location
    # or to backtrack to a previous good location to explore further
    def backtrack_or_continue
      best = nil
      if @iterations_since_best >= @backtrack_cutoff * @max_hood_size
        @iterations_since_best = 0
        debug('backtracked to best')
        best = @best
      else
        best = @current_hood.best
      end
      if best[:parameters].nil?
        # this should never happen!
        best = @best        
      end
      best
    end

    # shift to the next neighbourhood
    def next_hood
      @hood_no += 1
      debug("entering hood # #{@hood_no}")
      self.update_neighbourhood_structure
      @current_hood = Hood.new(@distributions, @max_hood_size, @tabu)
    end

    # get the next neighbour to explore from the current hood
    def next_candidate
      @current = @current_hood.next
      # exhausted the neighbourhood?
      if @current_hood.last?
        debug(@current_hood.best)
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
      false
    end

  end # TabuSearch

end # BiOpSy