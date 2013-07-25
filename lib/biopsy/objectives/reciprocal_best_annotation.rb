# objective function to count number of conditioned
# reciprocal best usearch annotations

require 'objectivefunction.rb'

class ReciprocalBestAnnotation < BiOpSy::ObjectiveFunction

  def run(assemblydata, threads=6)
    puts "running objective: ReciprocalBestAnnotation"
    t0 = Time.now
    @threads = threads
    # extract assembly data
    @assembly = assemblydata[:assembly]
    @assembly_name = assemblydata[:assemblyname]
    @reference = assemblydata[:reference]
    # results
    return { :weighting => 1.0,
             :optimum => 26000,
             :max => 26000.0,
             :result => self.rbusearch,
             :time => Time.now - t0}
  end

  def rbusearch
    Dir.mkdir 'output'
    `rbusearch --query ../#{@assembly} --target ../#{@reference} --output output --cores #{@threads}`
    return `wc -l output/bestmatches.rbu`.to_i
  end
end