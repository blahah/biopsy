require_relative '../lib/biopsy/objectivehandler'
require 'pp'
require 'fileutils'
require 'csv'
require 'threach'
require 'logger'

# should be equal to the GROUPSIZE constant in combinate_params.rb
# combinate_params.rb: splits the output into GROUPSIZE folders
GROUPSIZE = 200.0

# number of threads to commit
THREAD_NUMBER = 1

# open the original csv file which doesn't include scafSeq sizes
csv_file = CSV.open('outputdata/merged_leaff_soapdt.csv').each.map{ |l| l }
# grab the headear of the original csv file
csv_file_headers = csv_file[0]
# grab the contents of the original csv file
csv_file_contents = csv_file[1..-1]

handler = BiOpSy::ObjectiveHandler.new
a = {:reference => 'Athaliana_167_protein.fa',
    :assemblyname => 'test',  
    :leftreads => 'inputdata/l.fq',
    :rightreads => 'inputdata/r.fq',
    :insertsize => 200,
    :insertsd => 50 }

puts "Saving results in: outputdata_test/objectiveFunctionOutput.csv"
puts "Started"

CSV.open("outputdatan/objectiveFunctionOuput.csv", "w") do |csv|
	# add the original header to the new csv file plus the scafSeq size column
	csv << csv_file_headers + ['d', 'k', 'brm', 'rba', 'ut', 'dr', 'time']
end

CSV.open("outputdatan/objectiveFunctionOuput.csv", "ab") do |csv|
	# loop through rows of original csv file calculating the size of each relevent scafSeq file
	csv_file_contents.each do |line|
		if line[14].to_i <= 34
			next
			pp line
		end
		# the following two lines finds the group directory of the output file
    	groupceil = (line[0].to_i / GROUPSIZE).ceil * GROUPSIZE
    	destdir = "#{(groupceil - (GROUPSIZE-1)).to_i}-#{groupceil.to_i}"
    	`gunzip outputdata/#{destdir}/#{line[0]}/#{line[0]}.scafSeq.gz`
    	puts ""
    	a[:assembly] = "outputdata/#{destdir}/#{line[0]}/#{line[0]}.scafSeq"
    	t1 = Time.now
    	ar = handler.run_for_assembly(a, 4, true, true)
    	time = Time.now-t1
    	`gzip outputdata/#{destdir}/#{line[0]}/#{line[0]}.scafSeq`
    	pp ar
    	puts "abort here"
    	abort('p1')

    	# add original line about the output file + scafSeq size to the updated csv file
		#mutex = Mutex.new
		#mutex.synchronize do
			#csv << line + [File.size("outputdata/#{destdir}/#{line[0]}/#{line[0]}.#{OUTPUT_FILE}")]
		#end

	end
end
puts "Finished"