# runs leaff on all *.scafSeq files in the outputdata directory
# only numSeqs and SPAN output table is captured, BASES output table is ignored
# saves results in outputdata/leaff_output.csv
require 'find'
require 'csv'

$assemblies_analysed = 0

# function used to apply regular expression to leaff output
# match represents the variable extracted, e.g n50
def matchString(match, source)
  if /#{match}([0-9]*)\n/.match(source) != nil
    return_variable = /#{match}([0-9]*)\n/.match(source)[1] 
    return return_variable
  else
    return nil
  end
end

# function which works with matchString to extract output from leaff
def extractSaveLeaffOutput(raw_leaff_output, assembly_id)
  $assemblies_analysed += 1
  output_variables = {}
  # split leaff output and pull all text after 'numSeqs' keyword
  raw_leaff_output = raw_leaff_output.split("numSeqs")[1].gsub(" ", '')
  # for most scafSeq files leaff provides two tables of data: SPAN and BASES, BASES table removed if present
  if /BASES/ =~ raw_leaff_output
    raw_leaff_output = raw_leaff_output.split("BASES")[0]
  end
  # extract variables from leaff output
  output_variables[:numSeqs] = raw_leaff_output.split("\n")[0]
  output_variables[:n50]   = matchString("n50", raw_leaff_output)
  output_variables[:smallest]   = matchString("smallest", raw_leaff_output)
  output_variables[:largest]   = matchString("largest", raw_leaff_output)
  output_variables[:totLen]   = matchString("totLen", raw_leaff_output)

  # map extracted variables into an array
  output_variables = output_variables.map{|key, value| value}

    # open csv file and save output
    CSV.open("outputdata/leaff_output.csv", "ab") do |csv|
      csv << [assembly_id] + output_variables
    end
end


puts "Started"

# get scafSeq.gz sizes from previously generated csv file to prevent analysis of empty scafSeq files
csv_file = CSV.open('outputdata/filenameToParameters_scafSeq.gzSizes.csv').each.map{ |l| l }
# add headers to csv file where output is saved
CSV.open("outputdata/leaff_output.csv", "ab") do |csv|
  csv << ["assembly_fileid,numSeqs,n50,smallest,largest,totLen"]
end

# loop through directories in outputdata
Dir.foreach('outputdata') do |directory_group|
  # skip directories . and .. (they are parent folders)
  next if directory_group == '.' or directory_group == '..' or !File.directory?("outputdata/#{directory_group}")
  # loop through each directory in outputdata
  Dir.foreach("outputdata/#{directory_group}") do |outputfile|
    # skip directories . and .. (they are parent folders)
    next if outputfile == "." or outputfile == ".."
    # if csv file filenameToParameters_scafSeq.gz states file size is 34 or smaller don't apply leaff (34 is empty)
    if csv_file[outputfile.to_i][9].to_i <= 34
      CSV.open("outputdata/leaff_output.csv", "ab") do |csv|
        csv << [outputfile]+[0,0,0,0,0]
      end
      $assemblies_analysed += 1
      next
    end
    # unzip scafSeq.gz file
    `gunzip outputdata/#{directory_group}/#{outputfile}/#{outputfile}.scafSeq.gz`
    # apply leaff to scafSeq.gz
    out = `leaff --stats outputdata/#{directory_group}/#{outputfile}/#{outputfile}.scafSeq 2>&1`
    # rezip scafSeq file
    `gzip  outputdata/#{directory_group}/#{outputfile}/#{outputfile}.scafSeq`
    # extract and save leaff output data, also pass and save assemblie number
    extractSaveLeaffOutput(out, outputfile)
  end
end
puts "Finished, analysed #{$assemblies_analysed}"