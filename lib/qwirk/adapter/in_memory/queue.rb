module Qwirk
  module Adapter
    module InMemory

      class Queue
        # TODO: Look into reimplementing using a Ruby Queue which is probably better performant
        # Size of the queue before it write-blocks.  If 0, messages will be dropped.  If -1, then it's unlimited.
        # TODO: Should implement a queue_full_strategy which would be publish_block, drop_oldest, drop_newest
        attr_accessor :name, :max_size

        def initialize(name)
          @name            = name
          @max_size        = 0
          @array_mutex     = Mutex.new
          @read_condition  = ConditionVariable.new
          @write_condition = ConditionVariable.new
          @array           = []
          @stopping        = false
        end

        def size
          @array.size
        end

        def stop
          return if @stopping
          @stopping = true
          @array_mutex.synchronize do
            @write_condition.broadcast
            @read_condition.broadcast
          end
        end

        def stopped?
          @array_mutex.synchronize do
            return @stopping && @array.empty?
          end
        end

        def interrupt_read
          @array_mutex.synchronize do
            @read_condition.broadcast
          end
        end

        # Block read until a message or we get stopped.
        def read(stoppable)
          @array_mutex.synchronize do
            until stoppable.stopped || (@stopping  && @array.empty?)
              if @array.empty?
                @read_condition.wait(@array_mutex)
              else
                @write_condition.signal
                return @array.shift
              end
            end
          end
          return nil
        end

        def write(obj)
          @array_mutex.synchronize do
            # We just drop the message if no workers have been configured yet
            while !@stopping
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
              @write_condition.wait(@array_mutex)
            end
            Qwirk.logger.warn "Queue has been stopped #{@name}, dropping message #{obj.inspect}"
          end
        end

        def to_s
          "queue:#{@name}"
        end
      end
    end
  end
end
