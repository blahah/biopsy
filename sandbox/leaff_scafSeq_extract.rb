# runs leaff on all *.scafSeq files in the outputdata directory
# only numSeqs and SPAN output table is captured, BASES output table is ignore
require 'find'
require 'pp'
require 'csv'

def matchString(match, source)
	if /#{match}([0-9]*)\n/.match(source) != nil
		return_variable = /#{match}([0-9]*)\n/.match(source)[1] 
		return return_variable
	else
		return nil
	end
end
def extractSaveLeaffOutput(raw_leaff_output)
	output_variables = {}
	raw_leaff_output = raw_leaff_output.split("numSeqs")[1].gsub(" ", '')
	if /BASES/ =~ raw_leaff_output
		raw_leaff_output = raw_leaff_output.split("BASES")[0]
	end
	output_variables[:numSeqs] = raw_leaff_output.split("\n")[0]
	output_variables[:n50]   = matchString("n50", raw_leaff_output)
	output_variables[:smallest]   = matchString("smallest", raw_leaff_output)
	output_variables[:largest]   = matchString("largest", raw_leaff_output)
	output_variables[:totLen]   = matchString("totLen", raw_leaff_output)

	output_variables = output_variables.map{|key, value| "#{value},"}
	output_variables[output_variables.length-1].chop!
	pp output_variables

    CSV.open("leaff_output.csv", "ab") do |csv|
   		mutex = Mutex.new	
    	mutex.synchronize do
    		csv << output_variables
    	end
    end
end


csv_file = CSV.open('outputdata/filenameToParameters_scafSeq.gzSizes.csv').each.map{ |l| l }
CSV.open("leaff_output.csv", "ab") do |csv|
	mutex = Mutex.new	
    mutex.synchronize do
    	csv << ["numSeqs,n50,smallest,largest,totLen"]
    end
end
Dir.foreach('outputdata') do |directory_group|
  next if directory_group == '.' or directory_group == '..' or !File.directory?("outputdata/#{directory_group}")
  Dir.foreach("outputdata/#{directory_group}") do |outputfile|
  	next if outputfile == "." or outputfile == ".."
  	next if csv_file[outputfile.to_i][9].to_i <= 34
  	`gunzip outputdata/#{directory_group}/#{outputfile}/#{outputfile}.scafSeq.gz`
  	out = `leaff --stats outputdata/#{directory_group}/#{outputfile}/#{outputfile}.scafSeq 2>&1`
  	`gzip  outputdata/#{directory_group}/#{outputfile}/#{outputfile}.scafSeq`

	extractSaveLeaffOutput(out)
  end
end

#pp extractLeaffOutput(raw)
#leaf --stats 1.scafSeq
# leaf --stats 1.scafSeq > 1.scafSeqData