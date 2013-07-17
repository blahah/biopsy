# test Bioinformatic Optimisation System
require_relative 'objectivehandler.rb'
require 'fileutils'
require 'csv'

# test files can be found on cluster in:
# ~/experiments/assemblyoptimisation/denovo/testset

# define a test assembly
a = { :assembly => 'testset/test2.fa',
      :reference => 'testset/ref.fa',
      :assemblyname => 'test',  
      :leftreads => 'testset/testl.fq',
      :rightreads => 'testset/testr.fq',
      :insertsize => 200,
      :insertsd => 50 }

# test objectivehandler
handler = BiOpSy::ObjectiveHandler.new

# test results
r = { "BadReadMappings"=>{:weighting=>1.0, :optimum=>0.0, :max=>1.0, :result=>1.0}, 
      "ReciprocalBestAnnotation"=>{:weighting=>1.0, :optimum=>26000.0, :max=>26000.0, :result=>0}, 
      "UnexpressedTranscripts"=>{:weighting=>1.0, :optimum=>0.0, :max=>33000.0, :result=>33000}
}
  
def test_dimension_reduction()
  # test how dimension-reduced value changes with varying inputs
  puts "exploring dimension reduction outputs"
  CSV.open('testdm.csv', 'w') do |out|
    out << %w(brm rba ut result)
    (0.0..1.0).step(0.1).each do |brm|
      r["BadReadMappings"][:result] = brm
      (0..26000).step(2600).each do |rba|
        r["ReciprocalBestAnnotation"][:result] = rba
        (0.0..1.0).step(0.1).each do |ut|
          r["UnexpressedTranscripts"][:result] = ut
          out << [brm, rba, ut, handler.dimension_reduce(r)]
        end
      end
    end
  end
  puts "done"
end

def test_objectives_work()
  # confirm that all three objectives work for the test input
  r = handler.run_for_assembly(a, 1)
  p r
end

def test_k_sweep_soapdt(handler)
  # k sweep has already been conducted - just run objectives on the output
  res = [['d', 'k', 'brm', 'rba', 'ut', 'dr', 'time']]
  l = 'l.pooled.keep.fq'
  r = 'r.pooled.keep.fq'
  a = { :assembly => 'transcripts.fa',
      :reference => 'Athaliana_167_protein.fa',
      :assemblyname => 'test',  
      :leftreads => '',
      :rightreads => '',
      :insertsize => 200,
      :insertsd => 50 }
  [1, 2, 4, 8, 16].each do |d|
    Dir.chdir(d.to_s) do
      # set path to reads
      a[:leftreads] = "../#{d*100000}#{l}"
      a[:rightreads] = "../#{d*100000}#{r}"
      (21..86).step(5).each do |k|
        Dir.chdir("k#{k}") do
          # copy in the reference
          `cp ../../Athaliana_167_protein.fa ./`
          # timer
          t1 = Time.now
          # run objectives
          ar = handler.run_for_assembly(a, 20, true, true)
          next if ar.nil?
          t = Time.now - t1
          print "ran for assembly #{d}k#{k} in #{t} seconds"
          # store results
          rr = ar[:results]
          brm = rr['BadReadMappings'][:result]
          rba = rr['ReciprocalBestAnnotation'][:result]
          ut = rr['UnexpressedTranscripts'][:result]
          res << [d, k, brm, rba, ut, ar[:reduced], t]
          # remove the copied in reference
          `rm Athaliana_167_protein.fa`
        end
      end
    end
  end
  # write all results to file
  CSV.open('soapkoptimisation.csv', 'w') do |out|
    res.each{ |line| out << line }
  end
end

# run test sweep
test_k_sweep_soapdt(handler)
