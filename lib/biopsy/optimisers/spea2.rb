require 'csv'
require 'pp'

module Biopsy
	class SPEA2
		attr_reader :current, :probability_of_cross
		attr_writer :probability_of_cross
		attr_accessor :population_size, :archive_size, :probability_of_cross
		def initialize(parameter_ranges, threads=8)
			@parameter_ranges = parameter_ranges
			@currently_mating = false
			@probability_of_cross = 0.94
			@population_size = 50
			@archive_size = 15
			@mutation_rate = 0.20
			@generation_handler = Generation.new(@population_size, @archive_size)
			@mating_handler = MatingHandler.new(@population_size, @probability_of_cross, @parameter_ranges, @mutation_rate)
		end
		def setup start_point
			@current = {:parameters => start_point, :score => nil}
			@best = @current
		end
		# accepts a parameter set and a score (which are added to population)
		# returns another parameter set to be scored which is then accepted next iteration
	  def run_one_iteration(parameters, score)
	  	self.run_one_mating_iteration(parameters, score) if @currently_mating == true
	    @current = {:parameters => parameters, :score => score}
	    # update best score?
	    self.update_best?
	    # push new parameter set into generation
	    @currently_mating = @generation_handler.add_new_individual(@current)
	    if @currently_mating == true
	    	# begin mating process
	    	# empty current population
	    	@generation_handler.population_array = []
	    	selected_to_mate = @mating_handler.select_mating_population(@generation_handler.archive_array)
	    	self.get_children_to_score(selected_to_mate)
	    	@children_to_score.pop[:parameters]
	    else
	    	# get next parameter set to score
	    	self.random_parameter_set
	    end
	  end
	  def get_children_to_score selected_to_mate
	  	@children_to_score = @mating_handler.run(selected_to_mate)
	  end
	  def run_one_mating_iteration(parameters, score)
	  	@generation_handler.add_new_individual({:parameters => parameters, :score => score})
	  	if @children_to_score.length == 1
	  		@currently_mating = false
	  	end
	  	@children_to_score.pop
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
			Hash[@parameter_ranges.map { |k, v| [k, v.sample] }]
		end
		# check if termination conditions are met
		def finished?
			true if rand < 0.00025
		end
		def best
			@best
		end
	end # Algorithm

	class Generation
		attr_accessor :population_array, :archive_array
		def initialize(population_size, archive_size)
			@archive_generation = ArchiveGeneration.new
			@population_size = population_size
			@archive_size = archive_size
			@population_array = []
			@archive_array = []
		end
		def add_new_individual individual
			@population_array << Individual.new(individual)
			# run generation
			if @population_array.length == @population_size
				self.run_generation
				true
			else
				false
			end
		end
		def run_generation
			@pop_and_archive = @population_array + @archive_array
			FitnessAssignment.run(@pop_and_archive)
			@archive_array = @archive_generation.run(@pop_and_archive, 10)
		end
	end # Generation

	class Individual
		attr_reader :parameters, :score, :fitness, :raw_fitness, :density, :distance_to_kth_point, :distance_to_origin
		attr_writer :parameters, :fitness, :raw_fitness, :density, :distance_to_kth_point
		def initialize(individual)
			@parameters = individual[:parameters]
			@score = individual[:score]
			@distance_to_origin = FitnessAssignment.distance_to_origin(@score)
		end
	end # Individual

	class FitnessAssignment
		def self.run generation
			self.score_raw_fitness(generation)
			self.score_density(generation)
			generation.each do |individual|
				individual.fitness = individual.density + individual.raw_fitness
			end
		end
		def self.distance_to_origin coordinates
			# coordinates is a hash of coordinates
			return rand(coordinates)
		end
		def self.distance_between_points(individual_one, individual_two)
			if (individual_one.score - individual_two.score) < 0
				return (individual_one.score - individual_two.score)*-1
			else
				return (individual_one.score - individual_two.score)
			end
		end
		def self.score_density generation
			generation_hash = map_points_distance(generation)

			find_distance_to_kth_point(generation_hash)

			generation_hash.each do |key,value|
				value[0].density = (1.to_f/(value[0].distance_to_kth_point+2))
			end
		end
		def self.map_points_distance generation
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
		def self.score_raw_fitness generation
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
		def self.find_distance_to_kth_point generation_hash
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
				archive = self.further_archive_selection(archive, archive_size)
			elsif archive.length > archive_size
				archive = self.archive_truncation(archive)
			end
			return archive
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
			return archive
		end
		def further_archive_selection archive, archive_size
			@generation.sort!{|a, b| a.fitness <=> b.fitness}
			@generation.clone.each do |individual|
				if archive.length < archive_size
					archive << individual 
					@generation.delete(individual)
				else
					break
				end
			end
			return archive
		end
	end # ArchiveGeneration

	class MatingHandler
		def initialize(population_size, probability_of_cross, parameter_ranges, mutation_rate)
			@probability_of_cross = probability_of_cross
			@parameter_ranges = parameter_ranges
			@population_size = population_size
			@mutation_rate = mutation_rate
		end
		def run selected_to_mate
			new_population = reproduce(selected_to_mate)
			return new_population
		end
		def select_mating_population archive
			Array.new(@population_size) {self.binary_tournament(archive)}
		end
		def binary_tournament(archive)
			individual_one = rand(archive.size)
			individual_two = rand(archive.size)
			individual_two = rand(archive.size) while individual_one == individual_two
			if archive[individual_one].fitness > archive[individual_two].fitness
				return archive[individual_one]
			else
				return archive[individual_two]
			end
		end
		def reproduce selected_to_mate
			# loop through selected
			# mate first with last
			# mate index 1 with index 2
			# mate index 2 with index 1
			# mate index 3 with index 4
			children = []
			selected_to_mate.each_with_index do |parent_one, index|
				if index == selected_to_mate.size+1
					parent_two = selected_to_mate[0]
				elsif index.modulo(2) == 1
					parent_two = selected_to_mate[index-1]
				else
					parent_two = selected_to_mate[index+1]
				end
				children << self.mate(parent_one, parent_two)
			end
			return children
		end
		def mate(parent_one, parent_two)
			child = self.crossover(parent_one, parent_two)
			child = self.mutation(child)
			return child
		end
		def crossover(parent_one, parent_two)
			return {:parameters => parent_one.parameters} if rand >= @probability_of_cross
			# create the hash if parameter_ranges that can be passed to the +:Individual:+ class
			child_parameters = {}
			parent_one.parameters.each do |parent_one_key, parent_one_value|
				if rand < 0.5
					child_parameters[parent_one_key.to_sym] = parent_one_value
				else
					child_parameters[parent_one_key.to_sym] = parent_two.parameters[parent_one_key.to_sym]
				end
			end
			return {:parameters => child_parameters}
		end
		def mutation child
			child[:parameters].each do |key, value|
				child[:parameters][key.to_sym] = @parameter_ranges[key.to_sym].sample(1)[0] if rand < @mutation_rate
			end
			return child
		end
	end # MatingHandler
end # Biopsy