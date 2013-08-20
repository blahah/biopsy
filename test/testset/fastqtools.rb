# fastq-tools

require 'bio-faster'

module FastQTools
  def self.check_paired(l, r)
    l_out = File.open('checked.' + l, 'w')
    r_out = File.open('checked.' + r, 'w')
    lhandle = Bio::Faster.new(l)
    rhandle = Bio::Faster.new(r)
    badpair = 0
    wronglen = 0
    first = true
    lhandle.each_record(:quality => :new).to_a.zip(rhandle.each_record(:quality => :new).to_a).each do |lread, rread|
      puts lread, rread if first
      first = false
      lhead, lseq, lqual = lread
      rhead, rseq, rqual = rread
      if lhead.gsub(/\/1$/,'') == rhead.gsub(/\/2$/, '')
        if lseq.length == lqual.length && rseq.length == rqual.length
          [lhead, lseq, '+', lqual].each do |line|
            l_out.puts line
          end
          [rhead, rseq, '+', rqual].each do |line|
            r_out.puts line
          end
        else
          wronglen += 1
        end
      else
        badpair += 1
      end
    end
    if badpair > 0 || wronglen > 0
      puts "pruned #{badpair} non-matching pairs and #{wronglen} reads with differing sequence and quality lengths"
      puts "fixed files are in checked.#{l} and checked.#{r}"
    else
      File.delete('checked.' + l)
      File.delete('checked.' + r)
      puts "all clear"
    end
  end

  def check_single()


  end
end

FastQTools.check_paired('testl.fq', 'testr.fq')