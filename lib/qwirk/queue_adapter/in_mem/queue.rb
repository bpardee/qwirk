module Qwirk
  module QueueAdapter
    module InMem

      class Queue
        # TODO: Look into reimplementing using a Ruby Queue which is probably better performant
        # Size of the queue before it write-blocks.  If 0, messages will be dropped.  If -1, then it's unlimited.
        # TODO: Should implement a queue_full_strategy which would be publish_block, drop_oldest, drop_newest
        attr_accessor :name, :max_size

        def initialize(name)
          @name                   = name
          @max_size               = 0
          @outstanding_hash_mutex = Mutex.new
          @read_condition         = ConditionVariable.new
          @write_condition        = ConditionVariable.new
          @close_condition        = ConditionVariable.new
          @array                  = []
          @stopped                = false
        end

        def size
          @array.size
        end

        def stop
          @stopped = true
          @outstanding_hash_mutex.synchronize do
            @write_condition.broadcast
            until @array.empty?
              @close_condition.wait(@outstanding_hash_mutex)
            end
            @read_condition.broadcast
          end
        end

        def interrupt_read
          @outstanding_hash_mutex.synchronize do
            @read_condition.broadcast
          end
        end

        # Block read until a message or we get stopped.  stoppable is an object that responds to stopped (a worker or some kind of consumer)
        def read(stoppable)
          @outstanding_hash_mutex.synchronize do
            until @stopped  || stoppable.stopped do
              unless @array.empty?
                @write_condition.signal
                return @array.shift
              end
              @read_condition.wait(@outstanding_hash_mutex)
            end
            return if stoppable.stopped
            # We're not persistent, so even though we're stopped we're going to allow our stoppables to keep reading until the queue's empty
            unless @array.empty?
              @close_condition.signal
              return @array.shift
            end
          end
          return nil
        end

        def write(obj)
          @outstanding_hash_mutex.synchronize do
            # We just drop the message if no workers have been configured yet
            while !@stopped
              if @max_size == 0
                Qwirk.logger.warn "No worker for queue #{@name}, dropping message #{obj.inspect}"
                return
              end
              if @max_size < 0 || @array.size < @max_size
                @array << obj
                @read_condition.signal
                return
              end
              # TODO: Let's allow various write_full_modes such as :block, :remove_oldest, ? (Currently only blocks)
              @write_condition.wait(@outstanding_hash_mutex)
            end
          end
        end

        def to_s
          "queue:#{@name}"
        end
      end
    end
  end
end
