require 'csv'
require 'pp'

class GeneticAlgorithm
	attr_reader :current
	def initialize(parameter_ranges, threads=8)
		@ranges = parameter_ranges
		@population_array = []
		@generation_handler = Generation.new(5, 5)
	end
	def setup start_point
		@current = {:parameters => start_point, :score => nil}
		@best = @current
	end
	# accepts a parameter set and a score (which are added to population)
	# returns another parameter set to be scored which is then accepted next iteration
  def run_one_iteration(parameters, score)
    @current = {:parameters => parameters, :score => score}
    # update best score?
    self.update_best?
    # push new parameter set into generation
    @generation_handler.add_new_individual(@current)
    # get next parameter set to score
    self.random_parameter_set
  end
	# return true if algorithm knows its own starting point
	def knows_starting_point?
		return true
	end
	def update_best?
    if @best[:score].nil? || @current[:score] > @best[:score]
      @best = @current.clone
      @iterations_since_best = 0
    else
      @iterations_since_best += 1
    end
  end
	# returns a parameter set to be used as the starting point
	def select_starting_point
		self.random_parameter_set
	end
	# generates a random parameter set
	def random_parameter_set
		Hash[@ranges.map { |k, v| [k, v.sample] }]
	end
	# check if termination conditions are met
	def finished?
	end
end # Algorithm

class Generation
	def initialize(population_size, archive_size)
		@environment = Environment.new
		@population_size = population_size
		@archive_size = archive_size
		@population_array = []
		@archive_array = []
	end
	def add_new_individual individual
		@population_array << Individual.new(individual, @environment)
		# run generation
		if @population_array.length == @population_size
			self.run_generation	
		end
	end

	def run_generation
		puts "reached pop size"
		@pop_and_archive = @population_array + @archive_array
		@environment.score_raw_fitness(@pop_and_archive)

		@environment.score_density(@pop_and_archive)
		abort('run_generation method')
	end
end # Generation

class Individual
	attr_reader :individual, :score, :fitness, :raw_fitness, :density, :distance_to_origin
	attr_writer :fitness, :raw_fitness, :density
	def initialize(individual, environment)
		@environment = environment
		@individual = individual[:parameters]
		@score = individual[:score]
		@distance_to_origin = environment.distance_to_origin(@score)
	end
	# using Tournament class mate individual with another
	def mate_with
	end
end # Individual

class Individual_t
	attr_reader :individual, :score, :fitness, :raw_fitness, :density, :distance_to_origin
	attr_writer :fitness, :raw_fitness, :density
	def initialize(distance_to_origin)
		@distance_to_origin = distance_to_origin
	end
end

class Environment
	def distance_to_origin coordinates
		# coordinates is a hash of coordinates
		return rand(coordinates)
	end
	def score_density generation
		generation.each do |individual|
			
		end
	end
	def score_raw_fitness generation
		generation.sort! { |a, b| a.distance_to_origin <=> b.distance_to_origin }.reverse!
		counter = 0
		previous_distance = 9999
		generation.each do |individual|
			if previous_distance > individual.distance_to_origin
				individual.raw_fitness = counter
			else
				individual.raw_fitness = counter - 1
			end
			previous_distance = individual.distance_to_origin
			counter += 1
		end
	end
end # Environment

class Tournament
	def initialize
	end
end # Tournament

parameter_ranges = {
	:k => (1..10).to_a,
	:n => (1..1000).step(100).to_a
}
arr = GeneticAlgorithm.new(parameter_ranges, 5)
start_point = arr.select_starting_point
arr.setup(start_point)
pp arr.current
next_params = arr.run_one_iteration(start_point, rand(100))
(1..100).each do |num|
	next_params = arr.run_one_iteration(next_params, rand(120))
	pp arr.current
end

=begin
arr = Environment.new
generation = [Individual_t.new(20), Individual_t.new(18), Individual_t.new(18), Individual_t.new(15), Individual_t.new(10),]
arr.score_raw_fitness(generation)
=end