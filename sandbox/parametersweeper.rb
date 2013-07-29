# ParameterSweeper.new(options, constructor)
# options = {:settings => {...}, :parameters => {...}}
# Description:
# ParameterSweeper generates all combinations of a hash of arrays (options[:parameters]).
# Aforementioned combinations are applied to the constructor proc
# The constructor will also have access to an unchanging settings hash (options[:settings])
# constructor proc will be passed multipule hashes in format: {:settings => {...}, :parameters => {...}}
# where the values in settings remain constant, and the values in parameters vary 

require 'pp'
require 'fileutils'
require 'csv'
require 'threach'
require 'logger'

# options - is a hash of two hashes, :settings and :parameters
#   :settings are unchanging values passed to the constructor
#   :parameteres are arrays to be parameter sweeped 
#     ---(single values may be present, these are also remain unchanged but are accessible within the parameters hash to the constructor)
# constructor - a proc which is passed the 'options' hash containing a unchanging settings hash and a parametersweep parameters hash
class ParameterSweeper
  def initialize(options, constructor)
    # constructor: proc to build command from input_parameters hash
    @constructor = constructor
    # input_parameters: a hash containing parameters (which undergo parameter sweep) and an unchanging settings hash
    @input_parameters = options
    # parameter_counter: a count of input parameters to be used
    @parameter_counter = 1
    # input_combinations: an array of arrays of input parameters
    @input_combinations = []
    # if the number of threads is set, update the global variable, if not default to 1
    if @input_parameters[:settings][:threads]
      @threads = @input_parameters[:settings][:threads]
    else
      @threads = 1
    end
    # convert all options to an array so it can be handled by the generate_combinations() method
    # ..this is for users entering single values e.g 4 as a parameter
    options[:parameters].each do |key, value|
      if value.is_a? Array
        @input_parameters[:parameters][key.to_sym] = value.to_a
      else
        @input_parameters[:parameters][key.to_sym] = [value]
      end
    end
  end

  # apply the parameter sweep on the algorithm and save results appropriately
  def run(groupsize, continue_on_crash=false)
    Dir.chdir('outputdata_refactor') do
      # generate the combinations of parameters to be applied to soapdt, stored in @input_parameters[:parameters]
      generate_combinations
      puts "Will perform #{@parameter_counter} assemblies"
      # output headers to csv file
      CSV.open("filenameToParameters.csv", "w") do |csv|
        csv << ['assembly_id'] + @input_parameters[:parameters].keys + ['time']
      end
      # loop through each parameter set
      #@input_combinations.threach(@threads) do |parr|
      @input_combinations.each do |parr|
        # generate the bash command by calling the constructor passed by the user
        # parameters which have been sweeped by generate_combinations have been saved as array elements in @input_combinations
        # unchanging settings which must be passed to the constructor are still saved in the @input_parameters[:settings] hash
        # merge the two above hashes into one hash (keeping the two sets of values distinct) and pass to the constructor
        cmd = @constructor.call({:parameters => parr}.merge!({:settings => @input_parameters[:settings]}))
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

  # generate all the parameter combinations to be applied
  def generate_combinations(index=0, opts={})
    if index == @input_parameters[:parameters].length

      # save generated parameters
      # @options.map{|key, value| opts[key.to_sym]}
      #  the options that the user wants to vary is saved in @options
      #  opts[key] will contain the value of each option for this current parameter set
      @input_combinations << {:o => @parameter_counter}.merge!(opts)
      @parameter_counter += 1
      return
    end
    key = @input_parameters[:parameters].keys[index]
    @input_parameters[:parameters][key].each do |value|
      opts[key] = value
      generate_combinations(index+1, opts)
    end
  end
end