require 'rubystats'
require 'set'

# TODO:
# - make distributions draw elements from the range, not just from distribution
# - capture data about how SD is changing
# - capture data about convergence
# - test on real SOAPdt data

module BiOpSy

  # a Distribution represents the probability distribution from
  # which the next value of a parameter is drawn. The set of all
  # distributions acts as a probabilistic neighbourhood structure.
  class Distribution

    # create a new Distribution
    def initialize(mean, range, increment)
      @mean = mean
      @sd = range.size / 3 # this is arbitrary - should we learn a good initial setting?
      @range = range
      @increment = increment
      self.generate_distribution
    end

    # generate the distribution
    def generate_distribution
      @dist = Rubystats::NormalDistribution.new(@mean, @sd)
    end

    # loosen the distribution by increasing the sd
    # and renerating
    def loosen
      @sd += @increment * @range.size
      self.generate_distribution
    end

    # tighten the distribution by reducing the sd
    # and regenerating
    def tighten
      @sd -= @increment * @range.size
      self.generate_distribution
    end

    # draw from the distribution
    def draw
      @dist.rng
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
        if n >= 10
          # taking too long to generate a neighbour, 
          # loosen the neighbourhood structure so we explore further
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

    attr_reader :current, :best

    def initialize(parameter_ranges, max_hood_size=50, time_limit=nil)
      @ranges = parameter_ranges
      # self.set_term_conditions time_limit
      # solution tracking
      @current = Hash[parameter_ranges.map { |param, range| [param, range.sample] }]
      @best = {:score => 0}
      # tabu list
      @tabu = Set.new
      @tabu_limit = nil
      @start_time = Time.now
      # neighbourhoods
      @max_hood_size = 50
      self.define_neighbourhood_structure
      @current_hood = BiOpSy::Hood.new(@distributions, @max_hood_size, @tabu)
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
      @best = @current if @current[:score] > @best[:score]
    end

    # use probability distributions to define the
    # initial neighbourhood structure
    def define_neighbourhood_structure
      # probabilities
      @distributions = {}
      @increment = 0.1 # proportion of the range by which to increment the SD
      @current.each_pair do |param, value|
        range = @ranges[param]
        @distributions[param] = BiOpSy::Distribution.new(value, range, @increment)
      end
    end

    # update the neighbourhood structure by adjusting the probability
    # distributions according to total performance of each parameter
    def update_neighbourhood_structure
      @current_hood.best[:parameters].each_pair do |param, value|
        range = @ranges[param]
        @distributions[param] = BiOpSy::Distribution.new(value, range, @increment)
      end
    end

    # shift to the next neighbourhood
    def next_hood
      self.update_neighbourhood_structure
      @current_hood = Hood.new(@distributions, @max_hood_size, @tabu)
    end

    # get the next neighbour to explore from the current hood
    def next_candidate
      @current = @current_hood.next
      # exhausted the neighbourhood?
      if @current_hood.last?
        p @current_hood.best
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


# simple test (move to real testing env soon)
ranges = {
  :a => (1..100).to_a,
  :b => (1..100).to_a,
  :c => (1..50).to_a
}

tabu = BiOpSy::TabuSearch.new(ranges) 

def fake_objective(a, b, c)
  # should be easy - convex function taken from http://www.economics.utoronto.ca/osborne/MathTutorial/CVNF.HTM
  #  f (x1, x2, x3) = x12 + 2x22 + 3x32 + 2x1x2 + 2x1x3
  a**2 + 2 * (b**2) + 3 * (c**2) + 2 * (a * b) + 2 * (a + c)
end

p tabu.current

(1..10000).each do |i|
  a, b, c = tabu.current[:a], tabu.current[:b], tabu.current[:c]
  score = fake_objective(a, b, c)
  # puts "a:#{a}, b:#{b}, c:#{c} => #{score}"
  tabu.run_one_iteration(tabu.current, score)
end