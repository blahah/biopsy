require 'csv'
require 'pp'

$global = 0

module Biopsy

  class Generation
    attr_reader :best, :population_homogenosity

    def initialize (population_size, parameter_ranges)
      @population_homogenosity = 0
      @population_size = population_size
      @current_generation = []
      @ranges = parameter_ranges
      @MUTATION_RATE = 0.40
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
      #pp @current_generation if $global%100 == 0
      $global += 1
      #homogeneous_test
      selection_process
      crossover

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
      while next_generation.length < @population_size
        select_chromosome = next_generation.sample(1)[0]
        next_generation << select_chromosome
      end
      while next_generation.length > @population_size
        select_chromosome_index = next_generation.index(next_generation.sample(1)[0])
        next_generation.delete_at(select_chromosome_index)
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

    def generateMutation chromosome
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

    def homogeneous_test
      homo_val = 0
      (0..(@current_generation.length-1)).each do |i|
         (i..(@current_generation.length-1)).each do |j|
            next if i == j
            @current_generation[i][:parameters].each do |key, val|
              homo_val += 1 if val == @current_generation[j][:parameters][key.to_sym]
            end
          end
      end
      n_value = @current_generation.length-1
      sum = (n_value/2)*(n_value+1)
      @population_homogenosity = (homo_val/(sum*@current_generation[0][:parameters].length).to_f)
    end

    def get_population
      if self.last?
        return @current_generation
      else
        return false
      end
    end

  end # Generation


  class GeneticAlgorithm
    attr_reader :current, :best, :generation_no, :get_homog

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
      @current_generation.next_chromosome(chromosome)

      if @current_generation.last?
        return self.update_ga
      end
      return @current
    end

    def update_ga
      # ... will run to next generation
      store = @current_generation.run_generation
      @current_generation.homogeneous_test
      @get_homog = @current_generation.population_homogenosity
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

  end # GeneticAlgorithm

end # Biopsy