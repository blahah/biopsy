# objective function to count number of conditioned
# reciprocal best usearch annotations

require 'objectivefunction.rb'

class ReciprocalBestAnnotation < BiOpSy::ObjectiveFunction

  def run(assemblydata, threads=24)
    puts "running objective: ReciprocalBestAnnotation"
    @threads = threads
    # extract assembly data
    @assembly = assemblydata[:assembly]
    @assembly_name = assemblydata[:assemblyname]
    @reference = assemblydata[:reference]
    # results
    return { :weighting => 1.0,
             :optimum => 26000,
             :max => 26000.0,
             :result => self.rbusearch}
  end

  def rbusearch
    Dir.mkdir 'output'
    `~/scripts/rbusearch/rbusearch.rb --query ../#{@assembly} --target ../#{@reference} --output output --cores #{@threads}`
    return `grep "^[1-2]" output/bestmatches.rbu | wc -l`.to_i
  end
end