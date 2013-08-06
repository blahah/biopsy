require 'pp'
require 'csv'

class Generation
	attr_reader :best

	def initialize (population_size, parameter_ranges)
		@population_size = population_size
		@current_generation = []
		@ranges = parameter_ranges
		@MUTATION_RATE = 0.1
    @best = {
      :parameters => nil,
      :score => 0.0
    }
	end

	# insert the next chromosome into the generation
	def next_chromosome (chromosome)
		@current_generation += [chromosome]
	end

	def update_best? (current)
		@best = current if current[:score] > @best[:score]
	end

	# is the generation now full?
	def last?
		return @current_generation.length == @population_size
	end

	def run_generation
		#puts "STARTING GENERATION #{@current_generation.length}"
		#pp @current_generation
		selection_process
		#puts "AFTER SELECTION GENERATION #{@current_generation.length}"
		#pp @current_generation
		crossover
		#puts "AFTER CROSSOVER GENERATION #{@current_generation.length}"
		#pp @current_generation

		return @current_generation
	end
	###################################
	# ----remainder stochastic sampling (stochastic universal sampling method)----
	# apply obj function on parameter_sets, rank parameter_sets by obj func score
	# scale obj func score to ranking where: highest rank=2, lowest rank=0
	# for each integer in rank reproduce += 1, for decimal allow random reproduction (based on size of decimal)
	def selection_process
		current_generation_temp = []
		#apply obj func on all params, store score in @current_generation[X][:score]
		@current_generation.each do |chromosome|
			current_generation_temp << {:parameters => chromosome[:parameters], :score => chromosome[:score]}
		end
		# sort @current_generation by objective function score (ASC), replace @current_generation w/ temporary array
		current_generation_temp.each do |set|
			if set[:score].is_a? Hash
				puts "hash here"
				pp current_generation_temp
				abort('now')
			end
		end
		@current_generation = current_generation_temp.sort {|a, b| a[:score] <=> b[:score]}
		# the highest rank is 2.0, generate step_size (difference in rank between each element)
		step_size = 2.0/(@current_generation.length-1)
		# counter to be used when assigning rank
		counter = 0
		# next_generation temporary array, @current_generation is replaced by next_generation after loop
		next_generation = []
		# switch scores with ranks
		@current_generation.each do |chromosome|
			# rank (asc) is the order in which the element appears (counter) times step_size so that the max is 2
			rank = counter * step_size
			next_generation << {:parameters => chromosome[:parameters], :score => rank} if rank >= 1.0
			next_generation << {:parameters => chromosome[:parameters], :score => rank} if rank >= 2.0
			next_generation << {:parameters => chromosome[:parameters], :score => rank} if rand <= rank.modulo(1)
			counter += 1
		end
		# if population is too small
		if @population_size-next_generation.length > @population_size/4
			chromosome = next_generation.shuffle.pop
			next_generation << chromosome if rand <= chromosome[:score]
		# if population is too big
		elsif next_generation.length-@population_size > @population_size/4
			chromosome = next_generation.shuffle.pop
			next_generation.slice!(next_generation.index(chromosome)) if rand <= (2.0-chromosome[:score])
		end
		# sort @current_generation by objective function score (ASC), replace @current_generation w/ temporary array
		@current_generation = next_generation.sort {|a, b| a[:score] <=> b[:score]}
		return
	end
	def crossover
		def mating_process(mother, father)
			children = [{:parameters=>{}}, {:parameters=>{}}]
			mother[:parameters].each do |mother_key, mother_value|
				if rand <= 0.5
					children[0][:parameters][mother_key.to_sym] = mother_value
					children[1][:parameters][mother_key.to_sym] = father[:parameters][mother_key.to_sym]
				else
					children[0][:parameters][mother_key.to_sym] = father[:parameters][mother_key.to_sym]
					children[1][:parameters][mother_key.to_sym] = mother_value
				end
			end
			return children
		end
		# mate the best quarter with the best half
		best_quarter_num = (@current_generation.length.to_f/4.0).round
		best_half_num = best_quarter_num

		best_quarter = @current_generation[-best_quarter_num..-1]
		best_half = @current_generation[-(best_quarter_num+best_half_num)..-(best_quarter_num+1)]
		children = []
		best_quarter.each do |father|
			twins = mating_process(best_half.shuffle!.pop, father)
			children += twins.map{|value| value}
		end
		(0..(children.length-1)).each do |num|
			@current_generation.delete_at(0)
		end
		children.each do |child|
			if @MUTATION_RATE > rand
				children.delete_at(children.index(child))
				children += [generateMutation(child)]
			end
		end

		@current_generation += children
		return true
	end
	def generateMutation(chromosome)
		if !@mutation_wheel
			@mutation_wheel = [{}, 0]
			total_param_ranges = 0
			@ranges.each do |key, value|
				next if value.length <= 1
				total_param_ranges += value.length
				@mutation_wheel[0][key.to_sym] = total_param_ranges
			end
			@mutation_wheel[1] = total_param_ranges
		end
		mutation_location = rand(1..@mutation_wheel[1])
		temp_options_params = Marshal.load(Marshal.dump(@ranges))
		@mutation_wheel[0].each do |key, value|
			next if value < mutation_location
			temp_options_params[key.to_sym].delete(chromosome[:parameters][key.to_sym])
			chromosome[:parameters][key.to_sym] = temp_options_params[key.to_sym].sample(1)[0]
			break
		end
		return chromosome
	end
	def test
	end
	def get_population
		if self.last?
			return @current_generation
		else
			return false
		end
	end
end
class GeneticAlgorithm
	attr_reader :current, :best, :generation_no

	def initialize (population_size, parameter_ranges)
		@ranges = parameter_ranges
		@population_size = population_size
		@current_generation = Generation.new(@population_size, @ranges)
    @best = {
      :parameters => nil,
      :score => 0.0
    }
	end

	def run
		nil
	end

	def run_one_iteration (parameters, score)
			@current = {:parameters => parameters, :score => score}
			# update best score?
			self.update_best? @current
			# push next chromosome to GA, generation will compute if population size is full
			return self.next_candidate @current
			# update tabu list
			#self.update_tabu
			#@current
	end

	def update_best? (current)
			# ... runs an identical method in GenerationHandler 
			@current_generation.update_best? current
			@best = current if current[:score] > @best[:score]
	end

	def next_candidate (chromosome)
		# .. will run update ga if @current_generation.last? is true
		@current_generation.next_chromosome (chromosome)

		if @current_generation.last?
			return self.update_ga
		end
		return @current
	end

	def update_ga
		# ... will run to next generation
		store = @current_generation.run_generation
		@current_generation = Generation.new(@population_size, @ranges)
		return store
	end

	def finished?
		false
	end
	##############################
	def generate_chromosome
		return Hash[@ranges.map { |param, range| [param, range.sample] }]
	end
	def get_population
		return @current_generation.get_population
	end
end





parameters = {
	:K => (21..77).step(8).to_a,
	:M => (0..3).to_a, # def 1, min 0, max 3 #k value
	:d => (0..6).step(2).to_a, # KmerFreqCutoff: delete kmers with frequency no larger than (default 0)
	:D => (0..6).step(2).to_a, # edgeCovCutoff: delete edges with coverage no larger than (default 1)
	:e => (2..12).step(5).to_a, # contigCovCutoff: delete contigs with coverage no larger than (default 2)
	:t => (2..12).step(5).to_a, # locusMaxOutput: output the number of transcriptome no more than (default 5) in one locus
}
# load test set
testset = {}

first = true
head = nil
all = []
metrics = {
  'n50' => 591,
  'largest' => 2105,
  'rba_result' => 839,
  'brm_paired' => 34428,
}

CSV.open('/home/pa354/Code/biopsy/sandbox/soapdt_sweep/n50.csv', 'r').each do |line|
  if first
    head = line.map { |s| s.to_sym }[0..5]
    first = false
    next
  end
  key = line[0..5].join(':')
  value = Hash[%w(n50 largest rba_result brm_paired).zip(line[6..-1].map { |v| v.to_i })]
  testset[key] = value
end


def get_score (parameters, testset)
	key = parameters.map {|key,value| value.to_s}.join(":")
	score = 0
	if testset.has_key? key
	  unless key.split(':').size == 6
	    p "key not found: #{key}" 
	    p "current: #{tabu.current}"
	  end
	  score = testset[key]["n50"]
	end
	return score
end

pop_size = 5
res = ""
count = 0
GA = GeneticAlgorithm.new(pop_size, parameters)
(1..10).each do |num|
	puts "num is #{num}"
	if res.is_a? Array
		puts "array!"
		count += 1
		puts "count is #{count}"
		puts "GENERATION->#{GA.best[:score]}"
		res_temp = Marshal.load(Marshal.dump(res))
		res_temp.each do |parameter_set|
			res = GA.run_one_iteration(parameter_set[:parameters], get_score(parameter_set[:parameters], testset))
		end
	else
		parameter_set = GA.generate_chromosome
		score = get_score(parameter_set, testset)
		res = GA.run_one_iteration(parameter_set, score)
	end
end
#puts GA.get_population
#puts GA.best