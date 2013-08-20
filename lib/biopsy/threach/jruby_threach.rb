require 'java'
java_import java.util.concurrent.ArrayBlockingQueue
java_import java.util.concurrent.TimeUnit
java_import org.jruby.exceptions.JumpException::BreakJump

module Threach
  
  DEBUG = false
  
  # Exception for when a consumer encounters a 'break'
  class ThreachBreak < RuntimeError; end
  # Exception to note that another thread has told the rest of us
  # to wind it down due to an error
  class ThreachNotMyError < RuntimeError; end
  # Exception that indicates that we've legitimately run out of data
  # to process
  class ThreachEndOfRun < RuntimeError; end
  
  
  # An ArrayBlockingQueue with reasonable defaults
  # for timeouts.
  
  class Queue < ArrayBlockingQueue
    MS = TimeUnit::MILLISECONDS
    
    # Create a new queue 
    # @param [Integer] size The size of the queue
    # @param [Integer] timeout_in_ms How long to wait when trying to push or pop
    # @return [Queue] the new queue
    def initialize (size=5, timeout_in_ms = 5)
      super(size)
      @timeout = timeout_in_ms
    end
    
    # Try to add an object to the queue
    # @param [Object] obj The object to push
    # @return [Boolean] true on success, false on timeout
    def push obj
      self.offer obj, @timeout, MS
    end
    
    # Pop an object ouf of the queue
    # @return [Object, nil] nil if it times out; the popped object otherwise
    def pop
      self.poll @timeout, MS
    end
  end


  # A class that encapsulates several enumerables (that respond to the same 
  # enumerable with the same arity) and allows you to call them as if they
  # were a single enumerable (using multiple threads to draw from them, if
  # desired)
  class MultiEnum
    include Enumerable
    
    # The queue that acts as the common cache for objects pulled
    # from each of the enumerables
    attr_accessor :queue
    
    # Create a new MultiEnum
    # @param [Enumerable] enumerators A list of enumerators that you wish to act as a single enum
    # @param [Integer, nil] numthreads The number of threads to dedicate to pulling items 
    # @param [Symbol] iterator Which iterator to call against each enum
    # @param [Integer] size The size of the underlying queue
    #   off the enumerators and pushing them onto the shared queue. nil or zero implies one for
    #   each enumerator
    # @return [Threach::MultiEnum] the new multi-enumerator
    def initialize enumerators, numthreads=nil, iterator = :each, size = 5
      @enum = enumerators
      @iter = iterator
      @size = size
      @numthreads = (numthreads.nil? or numthreads == 0) ? enumerators.size : numthreads
      @queue = Threach::Queue.new(@size)
    end
    
    
    # Pull records out of the given enumerators using the number of threads
    # specified at initialization. Order of items is, obviously, not 
    # guaranteed.
    #
    # Also obviously, the passed block need to be of the same arity as the 
    # enumerator symbol passed into the intializer.
    # 
    # An uncaptured exception thrown by any of the enumerators will bring 
    # the whole thing crashing down. 
    def each &blk
      @producers = []
      tmn = -1
      @enum.each_slice(@numthreads).each do |eslice|
        tmn += 1
        @producers << Thread.new(eslice, tmn) do |eslice, tmn|
          Thread.current[:threach_multi_num] = "p#{tmn}"
          begin
            eslice.size.times do |i|
              eslice[i].send(@iter) do |*x|
                # puts "...pushing #{x}"
                @queue.put "#{Thread.current[:threach_multi_num]}: #{x}"
              end
            end
            @queue.put :threach_multi_eof
          rescue Exception => e
            @queue.put :threach_multi_eof
            raise StopIteration.new "Error in #{eslice.inspect}: #{e.inspect}"
          end
        end
      end

      done = 0
      
      while done < @numthreads
        d = @queue.take
        # puts "...pulling #{d}"
        if d == :threach_multi_eof
          done += 1 
          next
        end
        yield d
      end
      
      @producers.each {|p| p.join}
    end
  end
  
end

# Enumerable is monkey-patched to provide two new methods: #threach and 
# #mthreach. 
module Enumerable
  
  # Build up a MultiEnum from the calling object and run threach against
  # it
  # @param [Integer, nil] pthreads The number of producer threads to run within the 
  #   created Threach::MultiEnum
  # @param [Integer] threads The number of consumer threads to run in #threach
  # @param [Symbol] iterator Which iterator to call (:each, :each_with_index, etc.)
  # 
  # @example
  #   [1..10, 'a'..'z'].mthreach(2,2) {|i| process_item(i)}
  # 
  def mthreach(pthreads=nil, threads = 0, iterator = :each,  &blk)
    me = Threach::MultiEnum.new(self, pthreads, iterator, threads*3)
    me.send(:threach, threads, iterator, &blk)
  end
  
  # Run the passed block using the given iterator using the given 
  # number of threads. If one of the consumer threads bails for any reason
  # (break, throw an un-rescued error), the whole thing will shut down in an
  # orderly fashion.
  # @param [Integer] threads How many threads to use. 0 means to skip the whole 
  #   threading thing completely and just directly call the indicated iterator
  # @param [Symbol] iterator Which iterator to use (:each, :each_with_index, :each_line, 
  #   etc.). 
  def threach(threads = 0, iterator = :each, &blk)
    
    # With no extra threads, just spin up the passed iterator
    if threads == 0
      self.send(iterator, &blk)
    else
      # Get a java BlockingQueue for the producer to dump stuff into
      bq = Threach::Queue.new(threads * 2) # capacity is twice the number of threads
      
      # And another to store errors
      errorq = Threach::Queue.new(threads + 1)
      
      # A boolean to let us know if things are going wonky
      bail = false
      outofdata = false
      
      # Build up a set of consumers
      
      consumers = []
      threads.times do |i|
        consumers << Thread.new(i) do |i|
          Thread.current[:threach_num] = i
          begin
            while true
              obj = bq.pop

              # Should we be bailing?
              if bail
                print "Thread #{Thread.current[:threach_num]}: BAIL!\n" if Threach::DEBUG
                Thread.current[:threach_bail] = true
                raise Threach::ThreachNotMyError.new, "bailing", nil
              end
              
            
              # If the return value is nil, it timed out. See if there's
              # anything wrong, or if we've run out of work
              if obj.nil?
                if outofdata
                  Thread.current[:threach_outofdata] = true
                  raise Threach::ThreachEndOfRun.new, "out of work", nil
                end
                # otherwise, try to pop again
                next 
              end
              
              # Otherwise, do the work
              blk.call(*obj)
            end
          
          rescue Threach::ThreachNotMyError => e
            print "Thread #{Thread.current[:threach_num]}: Not my error\n" if Threach::DEBUG
            Thread.current[:threach_bail] = true            
            # do nothing; wasn't my error, so I just bailed
          
          rescue Threach::ThreachEndOfRun => e
            print "Thread #{Thread.current[:threach_num]}: End of run\n" if Threach::DEBUG
            Thread.current[:threach_bail] = true            
            # do nothing; everything exited normally 
            
          rescue Exception => e
            print "Thread #{Thread.current[:threach_num]}: Exception #{e.inspect}: #{e.message}\n" if Threach::DEBUG
            # Some other error; let everyone else know
            bail = true
            Thread.current[:threach_bail]
            errorq.push e
          ensure
            # OK, I don't understand this, but I'm unable to catch org.jruby.exceptions.JumpException$BreakJump
            # But if I get here and nothing else is set, that means I broke and need to deal with
            # it accordingly
            unless Thread.current[:threach_bail] or Thread.current[:threach_outofdata]
              print "Thread #{Thread.current[:threach_num]}: broke out of loop\n" if Threach::DEBUG
              bail = true
            end
          end
        end
      end
      
      
      # Now, our producer
      
      # Start running the given iterator and try to push stuff
      
      begin
        if iterator.kind_of? Array
          self.send(*iterator) do |*x|
            until successful_push = bq.push(x)
              # if we're in here, we got a timeout. Check for errors
              raise Threach::ThreachNotMyError.new, "bailing", nil if bail
            end
            print "Queued #{x}\n" if Threach::DEBUG
          end
        else
          self.send(iterator) do |*x|
            until successful_push = bq.push(x)
              # if we're in here, we got a timeout. Check for errors
              raise Threach::ThreachNotMyError.new, "bailing", nil if bail
            end
            print "Queued #{x}\n" if Threach::DEBUG
          end
        end

        # We're all done. Let 'em know
        print "Setting outofdata to true\n" if Threach::DEBUG
        outofdata = true
      
      rescue NativeException => e
        print "Producer rescuing native exception #{e.inspect}" if Threach::DEBUG
        bail = true
      
      rescue Threach::ThreachNotMyError => e
        print "Producer: not my error\n" if Threach::DEBUG
        # do nothing. Not my error
        
      rescue Exception => e
        print "Producer: exception\n" if Threach::DEBUG
        bail = true
        errorq.push e
      end
      
      # Finally, #join the consumers
      
      consumers.each {|t| t.join}
      
      # Everything's done. If there's an error on the stack, raise it
       if e = errorq.peek
         print "Producer: raising #{e.inspect}\n" if Threach::DEBUG
         raise e, e.message, nil
       end

    end
  end
end

__END__

class DelayedEnum
  include Enumerable
  
  def initialize coll
    @coll = coll
  end
  
  def each &blk
    @coll.each do |i|
      sleep 0.1
      yield i
    end
  end
end

c = DelayedEnum.new((1..10).to_a)
d = DelayedEnum.new(('A'..'N').to_a)
e = DelayedEnum.new((20..30).to_a)
f = DelayedEnum.new(('m'..'z').to_a)

[c,d,e,f].mthreach(2,2) {|i| print "#{Thread.current[:threach_num]}: #{i}\n"}
  