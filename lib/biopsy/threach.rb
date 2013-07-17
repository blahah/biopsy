require 'thread'

# Get a unique error class. We need this because
# consumer threads may exit in a couple ways; first by
# running out of input from the producer, and second by
# having a 'break' thrown.
class ThreachDone < LocalJumpError; end

# Monkey-patch Enumerable to allow threach (threaded-each)

module Enumerable
  # Provide an each-like iterator that uses the main thread to produce
  # work (generally via the underlying #each, but can use any method with
  # the optional arguments, e.g., each_with_index or each_line) and a
  # set of consumer threads to do the work specified in the passed block.
  #
  # Under the hood, threach populates a thread-safe queue with work from a
  # producer thread and uses the specified number of consumer threads to do the work.
  #
  # Note that threach is designed to be thread-safe internally, but the code you pass
  # in via the block also has to be thread-safe (e.g., if your database isn't
  # thread-safe, you can't be using it willy-nilly with three threads at a time). threach
  # is syntactic sugar only; it doens't magically make things thread-safe.
  #
  # NOTE: threach is just sugar over normal Thread operations. You can set thread-local variables
  # in the normal way -- by calling Thread.current[:var] = 'value'. If for some reason you want it, 
  # the thread number is stored in Thread.current[:tnum]. 
  #
  # @param [Integer] threads The number of consumer threads to spin up. A value of zero indicates that work should just be done serially
  # @param [Symbol] iterator The already-existing iterator to use to create work for the consumers. The output of the iterator is fed to the passed block, so if your chosen iterator produces two values (e.g.,  each_with_index) your block should, too (see below) 
  # @param [Block] &blk The block representing the conumer's work.
  #
  #
  # @example Use two threads to check URLs
  #   urls.threach(2) {|url|
  #     see_if_url_is_there(url)
  #   }
  #
  # @example Process lines of a file using three threads
  #   File.open('myfile') do |f|
  #     f.threach(3, :each_line) do |line|
  #       process_line(line)
  #     end
  #   end
  #
  # @example Process items in a hash (to show two-valued items for consumption)
  #   myBigHash.threach(2, :each_with_index) do |k,v|
  #    puts "The value of #{k} is #{v}"
  #   end

  def threach(threads=0, iterator=:each, &blk)
    
    # If 0 is passed, just treat it like any sequential call. 
    # Hence arr.threach(0) is exactly the same as arr.each
    if threads == 0
      self.send(iterator) do |*args|
        blk.call *args
      end
    else
      # Hang onto the main thread so we can bail out of it if need be
      producer_thread = Thread.current
      
      # Create two SizedQueues (which are guaranteed thread-safe)
      
      # bq is where we put the work from the producer; make it quite a bit bigger
      # than the number of threads so they don't spend too much time waiting on 
      # the producer.
      bq = SizedQueue.new(threads * 3)
      
      # doneq is, essentially, a thread-safe counter. MRI doesn't have thread-safe
      # integer operations on variables, so I'm just using this because I'm lazy.
      # We know when doneq.size == number_of_threads that the producer should be 
      # bailing if it isn't already done. This can happen when there is a 
      # "break" statement in the passed block.
      doneq = SizedQueue.new(threads)
      
      # Build up the consumers.
      consumers = []
      threads.times do |i|
        consumers << Thread.new(i) do |i|
          begin
            # Internal variable for debugging.
            Thread.current[:tnum] = i
            
            # Check to see if the popped value is the magical symbol
            # :end_of_data. If it is, stop, because the producer has 
            # run out of work. Otherwise, make the call.
            until (a = bq.pop) === :end_of_data
              blk.call(*a)
            end
          ensure
            # If we get to this ensure block, it means there was a non-normal
            # exit from the block via break. If that's the case, we push another
            # entry into the doneq.
            doneq << :threach_all_done
            
            # When the size of doneq == the number of threads, that means all
            # of the threads are done and we need to manually break out of the
            # producer thread by raising an error
            if doneq.size == threads
              producer_thread.raise(ThreachDone.new, :all_threads_done, nil)
            end            
            
          end
            
        end          
      end
    
      # The producer
      begin
        count = 0
        if iterator.kind_of? Array
          self.send(*iterator) do |*x|
            bq.push x
            count += 1
          end
        else
          self.send(iterator) do |*x|
            bq.push x
            count += 1
          end
        end
        # Here we've run out of stuff, so we need to signal to the 
        # threads that it's time to die. Next time they pop a value
        # off the queue, it'll be :end_of_data and they'll stop.
        #
        # Make sure we push one for each thread!
        threads.times do 
          bq << :end_of_data
        end
        
        
        # That's the end of the producer proper. Now we just join all the
        # consumer threads and we're set.
        consumers.each {|t| t.join}
        
      rescue ThreachDone => e
        # Do nothing; if we get here, it's because all the consumer threads
        # bailed via "break" for some reason.
      end
    end
  ensure
  end
    
end
