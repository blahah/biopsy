# search through outputdata files looking for *.scafSeq.gz
# unzip *.scafSeq.gz and record filesize in fileNameToParameters.csv
require 'csv'
require 'threach'
require 'pp'

# should be equal to the GROUPSIZE constant in combinate_params.rb
# combinate_params.rb: splits the output into GROUPSIZE folders
GROUPSIZE = 200.0

# which output file size are we measuring
OUTPUT_FILE = "scafSeq.gz"

# number of threads to commit
THREAD_NUMBER = 6

# open the original csv file which doesn't include scafSeq sizes
csv_file = CSV.open('outputdata/filenameToParameters.csv').each.map{ |l| l }
# grab the headear of the original csv file
csv_file_headers = csv_file[0]
# grab the contents of the original csv file
csv_file_contents = csv_file[1..-1]

puts "Saving results in: outputdata/filenameToParameters#{OUTPUT_FILE}Sizes.csv"
puts "Started"
CSV.open("outputdata/filenameToParameters_#{OUTPUT_FILE}Sizes.csv", "ab") do |csv|
	# add the original header to the new csv file plus the scafSeq size column
	csv << csv_file_headers + ["#{OUTPUT_FILE} size"]
	# loop through rows of original csv file calculating the size of each relevent scafSeq file
	csv_file_contents.threach(THREAD_NUMBER) do |line|

		# the following two lines finds the group directory of the output file
    	groupceil = (line[0].to_i / GROUPSIZE).ceil * GROUPSIZE
    	destdir = "#{(groupceil - (GROUPSIZE-1)).to_i}-#{groupceil.to_i}"

    	# add original line about the output file + scafSeq size to the updated csv file
		mutex = Mutex.new
		mutex.synchronize do
			csv << line + [File.size("outputdata/#{destdir}/#{line[0]}/#{line[0]}.#{OUTPUT_FILE}")]
		end

	end
end
puts "Finished"