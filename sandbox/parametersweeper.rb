require 'pp'
require 'fileutils'
require 'csv'
require 'threach'
require 'logger'

$SOAP_file_path = '/bio_apps/SOAPdenovo-Trans1.02/SOAPdenovo-Trans-127mer'

soap_constructor = Proc.new { |input_hash|
  constructor = "#{$SOAP_file_path} all -s soapdt.config"
  constructor += input_hash.map {|key, value| " -#{key} #{value}"}.join(",").gsub(",", "")
  constructor
}

class ParameterSweeper
  def initialize(options, constructor)
    # constructor: commands to pass to soapdt
    @constructor = constructor
    # input_parameters: hash of options produced by user
    @input_parameters = options
    # parameter_counter: a count of input parameters to be used
    @parameter_counter = 1
    # input_combinations: an array of arrays of input parameters
    @input_combinations = []
    # if the number of threads is set, update the global variable, if not default to 1
    if @input_parameters[:threads]
      @threads = @input_parameters[:threads]
      # remove this key from the hash, otherwise it will be put under parameter sweep
      @input_parameters.delete(:threads)
    else
      @threads = 1
    end
    # convert all options to an array so it can be handled by the generate_combinations() method
    # ..this is for users entering single values e.g 4 as a parameter
    options.each do |key, value|
      if value.is_a? Array
        @input_parameters[key.to_sym] = value.to_a
      else
        @input_parameters[key.to_sym] = [value]
      end
    end
  end

  def run(groupsize, continue_on_crash=false)
    Dir.chdir('outputdata_refactor') do
      # generate the config file (soapdt.config) to be used by soapdt, exists in outputdata/
      generate_configfile
      # generate the combinations of parameters to be applied to soapdt, stored in @input_parameters
      generate_combinations
      puts "Will perform #{@parameter_counter} assemblies"
      # output headers to csv file
      CSV.open("filenameToParameters.csv", "w") do |csv|
        csv << ['assembly_id'] + @input_parameters.keys + ['time']
      end
      # loop through each parameter set
      @input_combinations.threach(@threads) do |parr|
        # generate the bash command by calling the constructor passed by the user
        cmd = @constructor.call(parr)
        # run soapdt and record time
        t0 = Time.now
        `#{cmd} > #{parr[:o]}.log`
        time = Time.now - t0
        # check for success in previous bash command
        if !$?.success?
          log = Logger.new(STDOUT)
          # spit fatal error unless user has allowed continuation of sweep under crash
          if continue_on_crash == false
            log.fatal("\n\tFatal error experienced: #{$?}\n\tWhen running: #{constructor}")
            abort()
          else
            log.warn("\n\tError experienced: #{$?}\n\tWhen running: #{constructor}")
            next
          end
        end
        
        # output progress
        if parr[:o]%1000==0
          puts "Currently on #{parr[:o]} / #{output_parameters.length}. This run took #{time}"
        end
        # assembly decides the directory group in which output file will be placed
        groupceil = (parr[:o] / groupsize).ceil * groupsize
        destdir = "#{(groupceil - (groupsize-1)).to_i}-#{groupceil.to_i}"
        # create the directory group (if not exist)
        Dir.mkdir(destdir) unless File.directory?(destdir)
        # create output file for output of current assembly number from soapdt
        Dir.mkdir("#{destdir}/#{parr[:o]}") unless File.directory?("#{destdir}/#{parr[:o]}")
        # loop through output files from soap and move output files to relevent directory
        Dir["#{parr[:o]}.*"].each do |file|
          # Dir['#{.parr[:o]}.*'] will grab the directory group file (destdir) of the first output in each destdir file and attempt to gzip
          if file == destdir then
            next
          end
          `gzip #{parr[:o]}.* 2> /dev/null`
          file = file.gsub(/\.gz/, '')
          # move produced files to directory group
          FileUtils.mv("#{file}.gz", "#{destdir}/#{parr[:o]}")
          # write parameters to filenameToParameters.csv which includes a reference of filename to parameters
          
        end
        mutex = Mutex.new
        CSV.open("filenameToParameters.csv", "ab") do |csv|
          mutex.synchronize do
            # map the parr hash to an array, a suitable format for csv
           csv << parr.map{|key, value| value} + [time]
          end
        end
      end
    end
  end

  # generate all the parameter combinations to be applied to soapdt
  def generate_combinations(index=0, opts={})
    if index == @input_parameters.length

      # save generated parameters
      # @options.map{|key, value| opts[key.to_sym]}
      #  the options that the user wants to vary is saved in @options
      #  opts[key] will contain the value of each option for this current parameter set
      @input_combinations << {:o => @parameter_counter}.merge!(opts)
      @parameter_counter += 1
      return
    end
    key = @input_parameters.keys[index]
    @input_parameters[key].each do |value|
      opts[key] = value
      generate_combinations(index+1, opts)
    end
  end

  def generate_configfile
    # make config file
    rf = @input_parameters[:readformat] == ['fastq'] ? 'q' : 'f'
    File.open("soapdt.config", "w") do |conf|
      conf.puts "max_rd_len=20000"
      conf.puts "[LIB]"
      conf.puts "avg_ins=#{@input_parameters[:insertsize][0]}"
      conf.puts "reverse_seq=0"
      conf.puts "asm_flags=3"
      conf.puts "rank=2"
      conf.puts "#{rf}1=#{@input_parameters[:inputDataLeft][0]}"
      conf.puts "#{rf}2=#{@input_parameters[:inputDataRight][0]}"
    end
    @input_parameters.delete(:readformat)
    @input_parameters.delete(:insertsize)
    @input_parameters.delete(:inputDataLeft)
    @input_parameters.delete(:inputDataRight)
  end
end

ranges = {
  :readformat => 'fastq',
  :insertsize => 200,
  :inputDataLeft => '../inputdata/l.fq',
  :inputDataRight => '../inputdata/r.fq',
  :K => (21..29).step(8).to_a,
  :M => (0..1).to_a, # def 1, min 0, max 3 #k value
  :d => (0..2).step(2).to_a, # KmerFreqCutoff: delete kmers with frequency no larger than (default 0)
  :D => (0..2).step(2).to_a, # edgeCovCutoff: delete edges with coverage no larger than (default 1)
  :G => (25..75).step(50).to_a, # gapLenDiff(default 50): allowed length difference between estimated and filled gap
  :L => [200], # minLen(default 100): shortest contig for scaffolding
  :e => (2..7).step(5).to_a, # contigCovCutoff: delete contigs with coverage no larger than (default 2)
  :t => (2..7).step(5).to_a, # locusMaxOutput: output the number of transcriptome no more than (default 5) in one locus
  :p => 1,
  :threads => 6
}

soapdt = ParameterSweeper.new(ranges, soap_constructor)
soapdt.run(200.00, true)
