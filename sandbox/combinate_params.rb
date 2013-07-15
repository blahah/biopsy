# Run soapdt with multipule combinations parameters

input_parameters = {
	:k => (1..4), # 1 2 3 4 
	:n => (1..2), # 1 2
  :m => (0..3)

}

require 'pp'
 
$ranges = {
  :K => (21..90).step(4).to_a,
  :M => (0..3).to_a, #Def 1, min 0, max 3
  :d => (0..10).to_a, #Def 0
  :D => (0..10).to_a, #Def: 1
  :G => (0..20).step(5).to_a, #Def: 50
  :L => (0..20).step(5).to_a, #Def 100
  :e => (0..10).to_a, #Def: 2
  :t => (1..15).to_a #Def: 5

}
 
def nested_loop(index, opts)
  if index == $ranges.length
    # run command
    #OAPdenovo all -s configFile [-a initMemoryAssumption -K kmer -d KmerFreqCutOff -D EdgeCovCutoff -M mergeLevel -e ContigCovCutoff -u -G gapLenDiff -L minContigLen -p n_cpu -r -t locusMaxOutput] -o Out

    pp opts
    return
  end
  key = $ranges.keys[index]
  for value in $ranges[key]
    opts[key] = value
    nested_loop(index + 1, opts)
  end
end
 
nested_loop(0, {})



def soapdt(k)
	puts "#{k}"
end

def soapdt1(k, l, r, first)
  # make config file
  rf = $opts.readformat == 'fastq' ? 'q' : 'f'
  File.open("soapdt.config", "w") do |conf|
    conf.puts "max_rd_len=20000"
    conf.puts "[LIB]"
    conf.puts "avg_ins=#{$opts.insertsize}"
    conf.puts "reverse_seq=0"
    conf.puts "asm_flags=3"
    conf.puts "rank=2"
    conf.puts "#{rf}1=#{l}"
    conf.puts "#{rf}2=#{r}"
    if !first
      conf.puts "[LIB]"
      conf.puts "asm_flags=2"
      conf.puts "rank=1" # prioritise the higher-k contigs in scaffolding
      conf.puts "longreads.fa"
    end
  end
  
  # construct command
  cmd = "/applications/soapdenovo-trans/SOAPdenovo-Trans-127mer all"
  cmd += " -s soapdt.config" # config file
  cmd += " -a 30" # memory assumption
  cmd += " -o k#{k}" # output directory
  cmd += " -K #{k}" # kmer size
  cmd += " -p #{$opts.threads}" # number of threads
  cmd += " -d 3" # minimum kmer frequency
  cmd += " -F" # fill gaps in scaffold
  cmd += " -M 1" # strength of contig flattening
  cmd += " -D 1" # delete edges with coverage no greater than
  cmd += " -L 200" # minimum contig length
  cmd += " -u" # unmask high coverage contigs before scaffolding
  cmd += " -e 2" # delete contigs with coverage no greater than
  cmd += " -t 5" # maximum number of transcripts from one locus
  # cmd += " -S" # scaffold structure exists

  # run command
  `#{cmd} > k#{k}.log`

  # cleanup unneeded files
  `mkdir k#{k}`
  `mv k#{k}.scafSeq k#{k}/transcripts.fa`
  `rm k#{k}.*`
end