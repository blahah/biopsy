# objective function to count number of conditioned
# reciprocal best usearch annotations

class FastestOptimum < Biopsy::ObjectiveFunction

  def run(optdata, threads=6)
    info "running objective: FastestOptimum"
    t0 = Time.now
    @threads = threads
    # extract input data
    @assembly = assemblydata[:assembly]
    @assembly_name = assemblydata[:assemblyname]
    @reference = assemblydata[:reference]
    # results
    res = self.rbusearch
    return { :weighting => 1.0,
             :optimum => 26000,
             :max => 26000.0,
             :time => Time.now - t0}.merge res
  end

  def essential_files
    return ['bestmatches.rbu']
  end

end