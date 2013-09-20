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
		@fitness_assignment = FitnessAssignment.new
		@archive_generation = ArchiveGeneration.new
		@population_size = population_size
		@archive_size = archive_size
		@population_array = []
		@archive_array = []
	end
	def add_new_individual individual
		@population_array << Individual.new(individual, @fitness_assignment)
		# run generation
		if @population_array.length == @population_size
			self.run_generation	
		end
	end

	def run_generation
		@pop_and_archive = @population_array + @archive_array
		@fitness_assignment.run(@pop_and_archive)
		@archive_generation.run(@pop_and_archive, 3)
	end
end # Generation

class Individual
	attr_reader :parameters, :score, :fitness, :raw_fitness, :density, :distance_to_kth_point, :distance_to_origin
	attr_writer :fitness, :raw_fitness, :density, :distance_to_kth_point
	def initialize(individual, fitness_assignment)
		@fitness_assignment = fitness_assignment
		@parameters = individual[:parameters]
		@score = individual[:score]
		@distance_to_origin = fitness_assignment.distance_to_origin(@score)
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

class FitnessAssignment
	def run generation
		self.score_raw_fitness(generation)
		self.score_density(generation)
		generation.each do |individual|
			individual.fitness = individual.density + individual.raw_fitness
		end
	end
	def distance_to_origin coordinates
		# coordinates is a hash of coordinates
		return rand(coordinates)
	end
	def distance_between_points(individual_one, individual_two)
		if (individual_one.score - individual_two.score) < 0
			return (individual_one.score - individual_two.score)*-1
		else
			return (individual_one.score - individual_two.score)
		end
	end
	def score_density generation
		generation_hash = map_points_distance(generation)

		find_distance_to_kth_point(generation_hash)

		generation_hash.each do |key,value|
			value[0].density = (1.to_f/(value[0].distance_to_kth_point+2))
		end
	end
	def map_points_distance generation
		generation_clone = generation.clone
		generation_hash = {}
		generation_length = generation.length
		(1..generation_length).each do |num|
			generation_hash[num.to_s] = [generation_clone.pop, {}]
		end
		generation_hash.each do |key, value|
			(1..generation_length).each do |num|
				next if key.to_i == num or generation_hash[key][1].has_key?(num.to_s)
				generation_hash[key][1][num.to_s] = distance_between_points(generation_hash[key][0], generation_hash[num.to_s][0])
				generation_hash[num.to_s][1][key] = distance_between_points(generation_hash[key][0], generation_hash[num.to_s][0])
			end
		end
		return generation_hash
	end
	def score_raw_fitness generation
		generation.sort! { |a, b| a.distance_to_origin <=> b.distance_to_origin }.reverse!
		counter = 0
		previous_distance = +1.0/0.0
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
	def find_distance_to_kth_point generation_hash
		kth_point = Math.sqrt(generation_hash.length).round(0)
		generation_hash.each do |key, value|
			sorted_distances_array = value[1].sort_by {|k,v| v}
			(1..sorted_distances_array.length).each do |num|
				if num == (kth_point-1)
					value[0].distance_to_kth_point = sorted_distances_array[num][1]
				end
			end
		end
	end
end # FitnessAssignment

class ArchiveGeneration
	def run(generation, archive_size)
		@generation = generation

		archive = fill_archive(@generation)

		if archive.length < archive_size
			self.further_archive_selection
		elsif archive.length > archive_size
			self.archive_truncation(archive)
		end

	end
	def fill_archive generation
		archive = []
		@generation.clone.each do |individual|
			if individual.fitness < 1
				archive << individual 
				@generation.delete(individual)
			end
		end
		return archive
	end
	def archive_truncation archive

	end
	def further_archive_selection
		pp @generation
		# need to sort array of objects (@generation) by fitness which is a property of aforementioned objects
		# for some reason the fitness attribute of the objects in @generation is not accessible in the way presented below
		@generation.sort_by!{|a, b| a.fitness <=> b.fitness}
		pp @generation
	end
end # ArchiveGeneration
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
next_params = arr.run_one_iteration(start_point, rand(100))
(1..100).each do |num|
	next_params = arr.run_one_iteration(next_params, rand(120))
end

=begin
arr = FitnessAssignment.new
generation = [Individual_t.new(20), Individual_t.new(18), Individual_t.new(18), Individual_t.new(15), Individual_t.new(10),]
arr.score_raw_fitness(generation)
=end