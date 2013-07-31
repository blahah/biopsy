require_relative '../parametersweeper.rb'
require 'pp'
require 'threach'
require 'csv'

class GeneticAlgorithm
	def initialize(parameter_range, objective_function, time_limit=nil)
		# the number of times objective function is applied per generation
		@evaluations_per_generation = 2
		@population_size = 10
		@MUTATION_RATE = 0.01
		@THREADS = 1
		# set.map {|key, value| value}
		@parameter_range = []
		parameter_range.each do |set|
			@parameter_range << set.values
		end
		@objective_function = objective_function
		####@time_limit = time_limit

		# get the average time of evaluating one parameter set
		####@average_time = get_average_time(@parameter_range.sample(3))
		# to make the first generation get a random selection of the parameters in the parameter range
		# use average time calculated above to make a selection
		####@current_generation = @parameter_range.sample(@population_size))
		@current_generation = @parameter_range.sample(@population_size)
	end

	def run
		selection_process
		crossover
		# apply crossover
		# apply hillwalk
	end
	# assuming the most time intensive component is applying objective functions
	def get_average_time(parameters_to_test)
		t0 = Time.now
		# apply objective function to 3 parameters
		time = Time.now - t0

		# average time
		return (time/parameters_to_test)
	end
	# ----remainder stochastic sampling (stochastic universal sampling method)----
	# apply obj function on parameter_sets, rank parameter_sets by obj func score
	# highest rank=2, lowest rank=0
	# for each integer in rank reproduce += 1, for decimal allow random reproduction (based on size of decimal)
	def selection_process
		# apply objective function on parameter sets
		current_generation_temp = []
		@current_generation.each do |parameter_set|
			current_generation_temp << parameter_set + [@objective_function.call(parameter_set)]
		end
		# sort @current_generation by objective function score (ASC), replace @current_generation w/ temporary array
		@current_generation = current_generation_temp.sort {|a, b| a[-1] <=> b[-1]}
		# the highest rank is 2.0, generate step_size (difference in rank between each element)
		step_size = 2.0/(@current_generation.length-1)
		# counter to be used when assigning rank
		counter = 0
		# next_generation temporary array, @current_generation is replaced by next_generation after loop
		next_generation = []
		@current_generation.each do |parameter_set|
			# rank (asc) is the order in which the element appears (counter) times step_size so that the max is 2
			rank = counter * step_size
			# assign the array element previously holding obj func score as rank
			parameter_set[-1] = rank
			# (next two lines) for each integer in rank +1 to next_generation
			next_generation << parameter_set if rank >= 1
			next_generation << parameter_set if rank.to_i == 2
			# for decimal allow random reproduction (based on size of decimal)
			next_generation << parameter_set if rank.modulo(1) > rand
			counter += 1
		end
		# return new @current_generation
		@current_generation = next_generation
	end

	def crossover
		def mating_process(mother, father)
			children = [[],[]]
			counter = 0
			mother.each do |mother_element|
				#puts rand
				if rand <= 0.5
					children[0] << mother_element
					children[1] << father[counter]
				else
					children[0] << father[counter]
					children[1] << mother_element
				end
				counter += 1
			end
			return children
		end
		puts @current_generation.length
		pp @current_generation
		# mate the best quarter with the best half
		best_quarter_num = (@current_generation.length.to_f/4.0).floor
		puts "best quar #{best_quarter_num}"
		best_half_num = (@current_generation.length.to_f/2.0).ceil
		puts "best half #{best_half_num}"
		best_quarter = []
		best_half = []

		counter = 1
		@current_generation.reverse!.each do |parameter_set|
			if counter <= best_quarter_num
				best_quarter << parameter_set 
			elsif counter <= best_half_num
				best_half << parameter_set
			else
				break
			end
			counter +=1
		end
		children = []
		best_quarter.each do |father|
			mother_index_mated = rand(best_half.length())
			twins = mating_process(best_half[mother_index_mated], father)
			pp twins
			children << twins[0] + twins[1]
			best_half.delete_at(mother_index_mated)
		end
		current_generation_temp = []
		
		puts "children"
		pp children
		#pp best_quarter
		#puts "best half"
		#pp best_half

		# mutate children
		# return new @current_generation
	end

	def hillwalk
		# ?? Is hillwalk worth the extra objective function applications?
		# apply hillwalk on randomly children.
		# this random effect is heavily increased near end time
	end
end


objective_function = Proc.new { |parameter_set|
	score = nil
	# optimise csv reading ##
	CSV.foreach("objectiveFunctionOutput1.csv") do |c|
		score = c[42].to_f/c[39].to_f if c[0].to_i == parameter_set[0]
	end
	score
}

# constructor specific to soap
soap_constructor = Proc.new { |input_hash|  # make config file if doesn't already exist
  if !File.exist?("soapdt.config")
    rf = input_hash[:settings][:readformat] == 'fastq' ? 'q' : 'f'
    File.open("soapdt.config", "w") do |conf|
      conf.puts "max_rd_len=20000"
      conf.puts "[LIB]"
      conf.puts "avg_ins=#{input_hash[:settings][:insertsize]}"
      conf.puts "reverse_seq=0"
      conf.puts "asm_flags=3"
      conf.puts "rank=2"
      conf.puts "#{rf}1=#{input_hash[:settings][:inputDataLeft]}"
      conf.puts "#{rf}2=#{input_hash[:settings][:inputDataRight]}"
    end
  end
  constructor = "#{input_hash[:settings][:SOAP_file_path]} all -s soapdt.config"
  constructor += input_hash[:parameters].map {|key, value| " -#{key} #{value}"}.join(",").gsub(",", "")
  constructor
}
options = {
  # settings to be passed to the constructor
  :settings => {
    :SOAP_file_path => '/bio_apps/SOAPdenovo-Trans1.02/SOAPdenovo-Trans-127mer',
    :readformat => 'fastq',
    :insertsize => 200,
    :inputDataLeft => '../inputdata/l.fq',
    :inputDataRight => '../inputdata/r.fq',
    :threads => 2
  },
  # parameters to be sweeped
  :parameters => {
    :K => (21..29).step(8).to_a,
    :M => (0..1).to_a, # def 1, min 0, max 3 #k value
    :d => (0..2).step(2).to_a, # KmerFreqCutoff: delete kmers with frequency no larger than (default 0)
    :D => (0..2).step(2).to_a, # edgeCovCutoff: delete edges with coverage no larger than (default 1)
    :G => (25..75).step(50).to_a, # gapLenDiff(default 50): allowed length difference between estimated and filled gap
    :L => [200], # minLen(default 100): shortest contig for scaffolding
    :e => (2..7).step(5).to_a, # contigCovCutoff: delete contigs with coverage no larger than (default 2)
    :t => (2..7).step(5).to_a, # locusMaxOutput: output the number of transcriptome no more than (default 5) in one locus
    :p => 1,
  }
}
soapdt = ParameterSweeper.new(options, soap_constructor)

apply = GeneticAlgorithm.new(soapdt.showparams, objective_function)
apply.run