require_relative '../parametersweeper.rb'
require 'pp'
require 'threach'
require 'csv'

def ppp(obj)
	puts "[#{obj.map{|x| x.join(',') }.join("\n")}]"
end


class GeneticAlgorithm
	def initialize(parameter_range, objective_function, time_limit=nil)
		# the number of times objective function is applied per generation
		@evaluations_per_generation = 2
		@population_size = 10
		@MUTATION_RATE = 0.01
		@THREADS = 1
		@parameter_range = parameter_range
		#pp @parameter_range
		# set.map {|key, value| value}
		#@parameter_range = []
		#parameter_range.each do |set|
			#@parameter_range << set.values
		#end
		@objective_function = objective_function
		####@time_limit = time_limit

		# get the average time of evaluating one parameter set
		####@average_time = get_average_time(@parameter_range.sample(3))
		# to make the first generation get a random selection of the parameters in the parameter range
		# use average time calculated above to make a selection
		####@current_generation = @parameter_range.sample(@population_size))
		@current_generation = @parameter_range.sample(@population_size).map {|value| [value]}
	end

	def run
		#puts "------------------Starting population---------------------------------"
		#ppp @current_generation
		#puts "------------------Scores of starting population-----------------------"
		#@current_generation.each do |param|
			#puts @objective_function.call(param)
		#end
		puts "-----#{@current_generation.length}----START"
		(1..1000).each do |num|
			# puts "---------------------#{num}-----------------------------------------"
			selection_process
			# puts "-------------------CROSSOVER:----------------------------------------"
			crossover
			# ppp @current_generation
			if num%100 == 0
				puts "-----#{@current_generation.length}----"
				prev_score = 0
				@current_generation.each do |param|
					prev_score = @objective_function.call(param) if @objective_function.call(param) > prev_score
				end
				puts prev_score
			end
			# puts "--------------------end #{num}--------------------------------------"
		end
		puts "-----#{@current_generation.length}----END"
		#puts "------------------Ending population------------------------------------"
		#ppp @current_generation
		#puts "------------------Scores of ending population--------------------------"
		prev_score = 0
		@current_generation.each do |param|
			#puts @objective_function.call(param)
			prev_score = @objective_function.call(param) if @objective_function.call(param) > prev_score
		end
		puts prev_score
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
	# scale obj func score to ranking where: highest rank=2, lowest rank=0
	# for each integer in rank reproduce += 1, for decimal allow random reproduction (based on size of decimal)
	def selection_process
		# apply objective function on parameter sets
		current_generation_temp = []
		@current_generation.each do |parameter_set|
			current_generation_temp << [parameter_set[0], @objective_function.call(parameter_set)]
		end
		# sort @current_generation by objective function score (ASC), replace @current_generation w/ temporary array
		@current_generation = current_generation_temp.sort {|a, b| a.last <=> b.last}
		# the highest rank is 2.0, generate step_size (difference in rank between each element)
		step_size = 2.0/(@current_generation.length-1)
		# counter to be used when assigning rank
		counter = 0
		# next_generation temporary array, @current_generation is replaced by next_generation after loop
		next_generation = []
		@current_generation.each do |parameter_set, score|
			# rank (asc) is the order in which the element appears (counter) times step_size so that the max is 2
			rank = counter * step_size
			# (next two lines) for each integer in rank +1 to next_generation
			next_generation << [parameter_set, rank] if rank >= 1.0
			next_generation << [parameter_set, rank] if rank == 2.0
			# for decimal allow random reproduction (based on size of decimal)
			next_generation << [parameter_set, rank] if rank.modulo(1) > rand
			counter += 1
		end
		# return new @current_generation
		@current_generation = next_generation
	end

	def crossover
		def mating_process(mother, father)
			children = [{}, {}]
			counter = 0
			mother[0].each do |mother_key, mother_value|
				if rand <= 0.5
					children[0][mother_key.to_sym] = mother_value
					children[1][mother_key.to_sym] = father[0][mother_key.to_sym]
				else
					children[0][mother_key.to_sym] = father[0][mother_key.to_sym]
					children[1][mother_key.to_sym] = mother_value
				end
				counter += 1
			end
			return children
		end
		# mate the best quarter with the best half
		best_quarter_num = (@current_generation.length.to_f/4.0).ceil
		best_half_num = best_quarter_num

		best_quarter = @current_generation[-best_quarter_num..-1]
		best_half = @current_generation[-(best_quarter_num+best_half_num)..-(best_quarter_num+1)]
		children = []
		best_quarter.each do |father|
			tt = best_half.shuffle!.pop
			twins = mating_process(tt, father)
			children += twins.map{|value| [value]}
		end
		(-children.length..-1).each do |num|
			@current_generation.delete_at(num)
		end
		children.each do |child|
			child.each do |element|
				if @MUTATION_RATE > rand
					# ... mutate the element
				end
			end
		end
		@current_generation += children
		return true
	end

	def hillwalk
		# ?? Is hillwalk worth the extra objective function applications?
		# apply hillwalk on randomly children.
		# this random effect is heavily increased near end time
	end
end
def read_file(file_name)
  file = File.open(file_name, "r")
  data = file.read
  file.close
  return data
end

objective_function = Proc.new { |parameter_set|
	score = 0
	prev_value = 0
	parameter_set[0].each do |key, value|
		next if value == nil
		score +=1 if value%3 == 0
		score +=2 if value > prev_value
		prev_value = value
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