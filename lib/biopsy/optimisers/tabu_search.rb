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
      @sd = range.size / 30.0 # this is arbitrary - should we learn a good initial setting?
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
      @sd -= @increment * @range.size unless (@sd <= 0.5)
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
          p "loosening distributions"
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
      @hood_no = 1
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
        mean = @ranges[param].index(value)
        range = @ranges[param]
        @distributions[param] = BiOpSy::Distribution.new(mean, range, @increment)
      end
    end

    # update the neighbourhood structure by adjusting the probability
    # distributions according to total performance of each parameter
    def update_neighbourhood_structure
      @current_hood.best[:parameters].each_pair do |param, value|
        range = @ranges[param]
        p range
        p value
        @distributions[param] = BiOpSy::Distribution.new(value, range, @increment)
      end
    end

    # shift to the next neighbourhood
    def next_hood
      @hood_no += 1
      p "entering hood # #{@hood_no}"
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


# # simple test (move to real testing env soon)
# ranges = {
#   :a => (1..100).to_a,
#   :b => (1..100).to_a,
#   :c => (1..50).to_a
# }

# #######
# # simple test with convex three-parameter function
# #######

# tabu = BiOpSy::TabuSearch.new(ranges) 

# def fake_objective(a, b, c)
#   # should be easy - convex function taken from http://www.economics.utoronto.ca/osborne/MathTutorial/CVNF.HTM
#   #  f (x1, x2, x3) = x12 + 2x22 + 3x32 + 2x1x2 + 2x1x3
#   # optimum is a=100, b=100, c=50, score=57800
#   a**2 + 2 * (b**2) + 3 * (c**2) + 2 * (a * b) + 2 * (a + c)
# end

# p tabu.current

# res = []

# (1..10000).each do |i|
#   a, b, c = tabu.current[:a], tabu.current[:b], tabu.current[:c]
#   score = fake_objective(a, b, c)
#   # puts "a:#{a}, b:#{b}, c:#{c} => #{score}"
#   tabu.run_one_iteration(tabu.current, score)
#   res << [tabu.best, tabu.hood_no]
# end

# require 'csv'
# CSV.open('fake_objective_opt.csv', 'w') do |csv|
#   csv << %w(a b c hood_no score)
#   res.each do |r, t|
#     csv << r[:parameters].map { |k, v| v } + [t, r[:score]]
#   end
# end

# p tabu.best

########
# test with n50 for SOAPdt dataset
########
require 'csv'

# set parameters
parameters = {
  :K => (45..77).step(8).to_a,
  :M => (0..3).to_a, # def 1, min 0, max 3 #k value
  :d => (0..6).step(2).to_a, # KmerFreqCutoff: delete kmers with frequency no larger than (default 0)
  :D => (0..6).step(2).to_a, # edgeCovCutoff: delete edges with coverage no larger than (default 1)
  :e => (2..12).step(5).to_a, # contigCovCutoff: delete contigs with coverage no larger than (default 2)
  :t => (2..12).step(5).to_a, # locusMaxOutput: output the number of transcriptome no more than (default 5) in one locus
}

p parameters[:K]

# load test set
testset = {}

first = true
head = nil
CSV.open('first_set.csv', 'r').each do |line|
  if first
    head = line.map { |s| s.to_sym }[0..5]
    first = false
    next
  end
  key = line[0..5].join(':')
  value = line[6]
  testset[key] = value.to_i
end

# setup
tabu = BiOpSy::TabuSearch.new(parameters) 

# run
res = []

(1..10000).each do |i|
  key = head.map { |s| tabu.current[s] }.join(':')
  unless testset.has_key? key
    p "key not found: #{key}" 
    p "current: #{tabu.current}"
  end
  score = testset[key]
  # puts "a:#{a}, b:#{b}, c:#{c} => #{score}"
  tabu.run_one_iteration(tabu.current, score)
  res << [tabu.best, tabu.hood_no]
end

p tabu.best