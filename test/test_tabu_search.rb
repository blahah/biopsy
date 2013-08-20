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
# test with SOAPdt dataset
########
require 'csv'
require_relative '../optimisers/tabu_search.rb'
require_relative '../optimisers/parameter_sweeper.rb'


# set parameters
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
  # 'n50' => 591,
  # 'largest' => 2105,
  # 'rba_result' => 839,
  'brm_paired' => 34428,
}

CSV.open('../sandbox/soapdt_sweep/test_set.csv', 'r').each do |line|
  if first
    head = line.map { |s| s.to_sym }[0..5]
    first = false
    next
  end
  key = line[0..5].join(':')
  value = Hash[%w(n50 largest rba_result brm_paired).zip(line[6..-1].map { |v| v.to_i })]
  testset[key] = value
end

# setup
tabu = nil

# runlargest
res = {} # store the full output of each runlargest, rba_result, brm_paired, ut_result

opt_iter = {} # store the iteration at which the optimum was reached

num_repeats = 10
max_iterations = 1000

ranges = {
  :@max_hood_size => [5, 10, 20, 30, 40, 50, 75, 100],
  :@starting_sd_divisor => [2, 5, 10, 20, 30, 40],
  :@sd_increment_proportion => [0.01, 0.05, 0.1, 0.15, 0.2],
  :@backtrack_cutoff => [1.5, 2, 2.5, 3]
}

sweeper = BiOpSy::ParameterSweeper.new(ranges)  

puts "testing #{sweeper.combinations.length} parameter sets for the optimisation algorithm"
puts metrics

metrics.each_pair do |metric, opt|
  mres = []
  mopt_iter = []
  opt_params = sweeper.run_one_iteration
  while(!opt_params.nil?)
    (1..num_repeats).each do |runid|
      tabu = BiOpSy::TabuSearch.new(parameters)
      opt_params.each_pair do |opt_param, value|
        tabu.instance_variable_set(opt_param, value)
      end
      (1..max_iterations).each do |iterid|
        key = head.map { |s| tabu.current[s] }.join(':')
        score = 0
        if testset.has_key? key
          unless key.split(':').size == 6
            p "key not found: #{key}" 
            p "current: #{tabu.current}"
          end
          score = testset[key][metric]
        end
        tabu.run_one_iteration(tabu.current, score)
        if tabu.best.has_key? :parameters
          mres << [opt_params, tabu.best, tabu.hood_no, runid, iterid]
        end
        if tabu.best[:score] == opt
          mopt_iter << [opt_params, iterid]
          break
        end
      end
    end
    opt_params = sweeper.run_one_iteration
  end
  res[metric] = mres
  opt_iter[metric] = mopt_iter
end

res.each_pair do |metric, mres|
  CSV.open("#{metric}.csv", 'w') do |csv|
    csv << ranges.keys + %w(runid iterid) + parameters.keys + %w(hood_no score)
    mres.each do |opt_params, r, t, runid, iterid|
      begin
        csv << opt_params.values + [runid, iterid] + r[:parameters].values + [t, r[:score]]
      rescue
        p r
      end
    end
  end
end

opt_iter.each_pair do |metric, mopt_iter|
  CSV.open("#{metric}_opt_iter.csv", 'w') do |csv|
    csv << ranges.keys + ['mopt_iter']
    mopt_iter.each do |opt_params, m|
      csv << opt_params.values + [m]
    end
  end
end