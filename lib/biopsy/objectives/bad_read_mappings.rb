# objective function to count number of 'bad' read
# pair mappings. parses sam file using flags to
# count read pairs in various categories

require 'objectivefunction.rb'
require 'sam'
if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
# we want real posix threads if possible
require 'jruby_threach'
else
require 'threach'
end

# meanings of SAM flag components, with index i
# being one more than the exponent 2 must be raised to to get the
# value (i.e. value = 2^(i+1))
$flags = [nil,
          0x1,  #    1. read paired 
          0x2,  #    2. read mapped in proper pair (i.e. with acceptable insert size)
          0x4,  #    3. read unmapped
          0x8,  #    4. mate unmapped
          0x10,  #   5. read reverse strand
          0x20,  #   6. mate reverse strand
          0x40,  #   7. first in pair
          0x80,  #   8. second in pair
          0x100,  #  9. not primary alignment
          0x200,  #  10. read fails platform/vendor quality checks
          0x400]  #  11. read is PCR or optical duplicate

class BadReadMappings < BiOpSy::ObjectiveFunction

  def run(assemblydata, threads=24)
    puts "running objective: BadReadMappings"
    @threads = threads
    # extract assembly data
    @assembly = assemblydata[:assembly]
    @assembly_name = assemblydata[:assemblyname]
    @left_reads = assemblydata[:leftreads]
    @right_reads = assemblydata[:rightreads]
    @insertsize = assemblydata[:insertsize]
    @insertsd = assemblydata[:insertsd]
    # realistic maximum insert size is three standard deviations from the insert size
    @realistic_dist = @insertsize + (3 * @insertsd)
    # run analysis
    self.map_reads
    # results
    return { :weighting => 1.0,
             :optimum => 0.0,
             :max => 1.0,
             :result => self.parse_sam}
  end

  def map_reads
    self.build_index
    unless File.exists? 'mappedreads.sam'
      # construct bowtie command
      bowtiecmd = "bowtie2 -k 3 -p #{@threads} -X #{@realistic_dist} --no-unal --fast-local --quiet #{@assembly_name} -1 ../#{@left_reads}"
      # paired end?
      bowtiecmd += " -2 ../#{@right_reads}" if @right_reads.length > 0
      # other functions may want the output, so we save it to file
      bowtiecmd += " > mappedreads.sam"
      # run bowtie
      `#{bowtiecmd}`
    end
  end

  def build_index
    unless File.exists?(@assembly + '.1.bt2')
      `bowtie2-build --offrate 1 ../#{@assembly} #{@assembly_name}`
    end
  end

   # colnames = %w(1:name 2:flag 3:chr 4:pos 5:mapq 6:cigar 7:mchr 8:mpos 9:insrt 10:seq 11:qual)

  def parse_sam
    if File.exists?('mappedreads.sam') && `wc -l mappedreads.sam`.to_i > 0
      ls = Sam.new
      rs = Sam.new
      good = 0
      bad = 0
      flags = {}
      File.open('mappedreads.sam').lines.each_slice(2) do |l, r|
        if l && ls.parse_line(l) # Returns false if line starts with @ (a header line)
          if r && rs.parse_line(r)
            # ignore unmapped reads
            flagpair = "#{ls.flag}:#{rs.flag}"
            if flags.has_key? flagpair
              flags[flagpair] += 1
            else
              flags[flagpair] = 1
            end
            unless ls.mapq == -1 or rs.mapq == -1
              unless ls.flag & $flags[1] && !ls.flag & $flags[8]
                # reads are paired
                if ls.flag & $flags[2]
                  # mapped in proper pair
                  if (ls.flag & $flags[6] && ls.flag & $flags[7]) || 
                     (ls.flag & $flags[5] && ls.flag & $flags[8])
                    # mates in proper orientation
                    good += 1
                  else
                    # mates in wrong orientation
                    bad += 1
                  end
                else
                  # not mapped in proper pair
                  unless (ls.flag & $flags[3]) || (ls.flag & $flags[4])
                    # both read and mate are mapped
                    if ls.chrom == rs.chrom
                      # both on same contig
                      if Math.sqrt(ls.pos - rs.pos ** 2) < ls.seq.length
                        # overlap is realistic
                        if (ls.flag & $flags[6] && ls.flag & $flags[7]) || 
                         (ls.flag & $flags[5] && ls.flag & $flags[8])
                          # mates in proper orientation
                          good += 1
                        else
                          # mates in wrong orientation
                          bad += 1
                        end
                      else
                        # overlap not realistic
                        bad += 1
                      end
                    else
                      # mates on different contigs
                      # are the mapping positions within a realistic distance of
                      # the ends of contigs?
                      lcouldpair = (ls.seq.length - ls.pos) < @realistic_dist
                      lcouldpair = lcouldpair || ls.pos < @realistic_dist
                      rcouldpair = (rs.seq.length - rs.pos) < @realistic_dist
                      rcouldpair = rcouldpair || rs.pos < @realistic_dist
                      if lcouldpair && rcouldpair
                        good += 1
                      else
                        bad += 1
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
      # puts flags
      return bad.to_f / ( good.to_f + bad )
    else
      return 0.0
      # raise 'Could not find mapped reads'
    end
  end
end

