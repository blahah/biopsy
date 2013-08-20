##############################################################################
##############################################################################
##############################################################################
##############################################################################
##############################################################################
##############################################################################

# load test set
testset = {}
$already_done = {}
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
  if $already_done[key.to_sym]
    return $already_done[key.to_sym]
  end
  #puts "SCORE #{$no_iter}"
  $no_iter += 1
  score = 0
  if testset.has_key? key
    unless key.split(':').size == 6
      p "key not found: #{key}" 
      p "current: #{tabu.current}"
    end
    score = testset[key]["n50"]
  end
  $already_done[key.to_sym] = score
  return score
end

##############################################################################
##############################################################################
##############################################################################
##############################################################################
##############################################################################
##############################################################################


# varied by param sweep
parameters = {
  :K => (21..77).step(8).to_a,
  :M => (0..3).to_a, # def 1, min 0, max 3 #k value
  :d => (0..6).step(2).to_a, # KmerFreqCutoff: delete kmers with frequency no larger than (default 0)
  :D => (0..6).step(2).to_a, # edgeCovCutoff: delete edges with coverage no larger than (default 1)
  :e => (2..12).step(5).to_a, # contigCovCutoff: delete contigs with coverage no larger than (default 2)
  :t => (2..12).step(5).to_a, # locusMaxOutput: output the number of transcriptome no more than (default 5) in one locus
}
mutation_rate = 0.3
pop_size = 10

# varied depending on how much time available
max_runs = 100
max_iter = 100

# output variables
no_fail = 0
no_done = 0
avg_iter = 0
total_iter = 0

$test = 0

(1..max_runs).each do |no_runs|
  puts "Run number: #{no_runs-1} Total iterations: #{total_iter} Iterations this run: #{$already_done.length}" #if no_runs%10 == 0
  # variables used during runs
  $no_iter = 0
  now_break = false
  first = true
  res = ""
  gen_Al = GeneticAlgorithm.new(pop_size, parameters)
  count = 0
  $already_done = {}

  # generation loop
  while true == true do 

    # break generation if max iter reached
    break if now_break == true

    # if first population has been inserted (res will also be an array)
    if first == false
      # loop through the resultant population adding members to the new generation
      res_temp = Marshal.load(Marshal.dump(res))
      res_temp.each do |parameter_set|
        #print "run"
        res = gen_Al.run_one_iteration(parameter_set[:parameters], get_score(parameter_set[:parameters], testset))
        # if max iter reached break current loop and generation loop
        if $no_iter == max_iter
          #puts "fail break #{$no_iter} #{gen_Al.best}"
          no_fail += 1
          now_break = true
          total_iter += $no_iter
          break
        end
      end
      count += 1
      #puts "\nrunid: #{no_runs} iterid: #{$no_iter} params: #{gen_Al.best[:parameters].map {|key, value| value}} score: #{gen_Al.best[:score]}" #if count%3 == 0
      # if best score reached break generation loop
      if gen_Al.best[:score] == 591
        no_done += 1
        avg_iter += $no_iter
        total_iter += $no_iter
        break
      end
    # if first population has not been inserted
    else
      # insert the first population set
      (1..pop_size).each do |n|
        parameter_set = gen_Al.generate_chromosome
        res = gen_Al.run_one_iteration(parameter_set, get_score(parameter_set, testset))
      end
      # the first population set has been inserted, update variable
      first = false
      # if best score reached break generation loop now
      if gen_Al.best[:score] == 591
        no_done += 1
        avg_iter += $no_iter
        total_iter += $no_iter
        break
      end
    end
  end
end



puts "no_done: #{no_done}, no_fail: #{no_fail}, percentage: #{no_done.to_f/max_runs}, avg iter: #{avg_iter/no_done}, total iter: #{total_iter/max_runs}"