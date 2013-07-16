# run soapdt with multipule combinations parameters
# output file name references input parameters

require 'pp'
require 'csv'
require 'trollop'
require 'threach'
require 'fileutils'

# splits the output into GROUPSIZE folders
GROUPSIZE = 200.0

$SOAP_file_path = '/bio_apps/SOAPdenovo-Trans1.02/SOAPdenovo-Trans-127mer'

# options passed to SOAPdenovo
$opts = {
  :readformat => 'fastq',
  :threads => 6,
  :insertsize => 200
}

# soapdt.config file only generated on first run
def setup_soap(l, r)
  if $firstrun
    # make config file
    rf = $opts[:readformat] == 'fastq' ? 'q' : 'f'
    File.open("soapdt.config", "w") do |conf|
      conf.puts "max_rd_len=20000"
      conf.puts "[LIB]"
      conf.puts "avg_ins=#{$opts[:insertsize]}"
      conf.puts "reverse_seq=0"
      conf.puts "asm_flags=3"
      conf.puts "rank=2"
      conf.puts "#{rf}1=#{l}"
      conf.puts "#{rf}2=#{r}"
    end
  end
end

# runs SOAPdt script
def run_soap(out, kcap, m, d, dcap, lcap, e, t)
  # construct command
  cmd = "#{$SOAP_file_path} all"
  cmd += " -s soapdt.config" # config file
  cmd += " -a 0.5" # memory assumption
  cmd += " -o #{out}" # output directory
  cmd += " -K #{kcap}" # kmer size
  cmd += " -p #{$opts[:threads]}" # number of threads
  cmd += " -d #{d}" # minimum kmer frequency
  cmd += " -F" # fill gaps in scaffold
  cmd += " -M #{m}" # strength of contig flattening
  cmd += " -D #{dcap}" # delete edges with coverage no greater than
  cmd += " -L #{lcap}" # minimum contig length
  cmd += " -u" # unmask high coverage contigs before scaffolding
  cmd += " -e #{e}" # delete contigs with coverage no greater than
  cmd += " -t #{t}" # maximum number of transcripts from one locus
  # cmd += " -S" # scaffold structure exists
  # run command

  # output saved to out.log where #{out} is assembly number
  `#{cmd} > #{out}.log`
end

# ranges of input parameters to be tested
$ranges = {
  :K => (21..80).step(8).to_a,
  :M => (0..3).to_a, # def 1, min 0, max 3 #k value
  :d => (0..6).step(2).to_a, # KmerFreqCutoff: delete kmers with frequency no larger than (default 0)
  :D => (0..6).step(2).to_a, # edgeCovCutoff: delete edges with coverage no larger than (default 1)
  :G => (25..150).step(50).to_a, # gapLenDiff(default 50): allowed length difference between estimated and filled gap
  :L => [200], # minLen(default 100): shortest contig for scaffolding
  :e => (2..12).step(5).to_a, # contigCovCutoff: delete contigs with coverage no larger than (default 2)
  :t => (2..12).step(5).to_a # locusMaxOutput: output the number of transcriptome no more than (default 5) in one locus
}
# iterative variables increases by +1 for each parameter set tested
$output_counter = 1
# output parameters are generated and stored as an array of arrays
# this global variable is then iterated applying the parameters stored within it to soapdt()
$output_parameters = []

# generate the array out output parameters
def nested_loop(index, opts)
  if index == $ranges.length
    # save generated parameters
    $output_parameters << [$output_counter, opts[:K], opts[:M], opts[:d], opts[:D], opts[:L], opts[:e], opts[:t]]
    $output_counter += 1
    return
  end
  key = $ranges.keys[index]
  $ranges[key].each do |value|
    opts[key] = value
    nested_loop(index+1, opts)
  end
end

# output stored in file: outputdata
Dir.mkdir('outputdata') unless File.directory?('outputdata')

Dir.chdir('outputdata') do
  nested_loop(0, {})
  puts "Will perform #{$output_parameters.length} assemblies"
  # produces the config file and loads data into soap
  setup_soap('../inputdata/l.fq', '../inputdata/r.fq')
  # csv file which relates number of filename to input parameters
  CSV.open("filenameToParameters.csv", "w") do |csv|
    csv << ['sample_id'] + $ranges.keys + ['time']
  end
  # initiate multithreading, loop through array of parameters to be inserted into soap
  $output_parameters.threach(6) do |parr|
    t0 = Time.now
    run_soap(parr[0], parr[1], parr[2], parr[3], parr[4], parr[5], parr[6], parr[7])
    time = Time.now - t0
    out = parr[0]
    # output progress
    if out%1000==0
      puts "Currently on #{out} / #{$output_parameters.length}. This run took #{time}"
    end
    # assembly decides the directory group in which output file will be placed
    groupceil = (out / GROUPSIZE).ceil * GROUPSIZE
    destdir = "#{groupceil - (GROUPSIZE-1)}-#{groupceil}"
    # create the directory group (if not exist)
    Dir.mkdir(destdir) unless File.directory?(destdir)
    # create output file for out of current assembly number from soapdt
    Dir.mkdir("#{destdir}/#{out}") unless File.directory?("#{destdir}/#{out}")
    # loop through output files from soap and move output files to relevent directory
    Dir["#{out}.*"].each do |file|
      # Dir['#{.out}.*'] will grab the directory group file (destdir) of the first output in each destdir file and attempt to gzip
      if file == destdir then
        next
      end
      `gzip #{out}.* 2> /dev/null`
      file = file.gsub(/\.gz/, '')
      # move produced files to directory group
      FileUtils.mv("#{file}.gz", "#{destdir}/#{out}")
    end

    # write parameters to filenameToParameters.csv which includes a reference of filename to parameters
    mutex = Mutex.new
    CSV.open("filenameToParameters.csv", "ab") do |csv|
      mutex.synchronize do
        csv << parr + [time]
      end
    end
  end
end