module Qwirk
  module Adapter
    module InMem

      class ReplyQueue
        def initialize(name)
          @name                   = name
          @outstanding_hash_mutex = Mutex.new
          @read_condition         = ConditionVariable.new
          @array                  = []
        end

        def timeout_read(timeout)
          @outstanding_hash_mutex.synchronize do
            return @array.shift unless @array.empty?
            timed_read_condition_wait(timeout)
            return @array.shift
          end
          return nil
        end

        def write(obj)
          @outstanding_hash_mutex.synchronize do
            @array << obj
            @read_condition.signal
            return
          end
        end

        def to_s
          "reply_queue:#{@name}"
        end

        #######
        private
        #######

        if RUBY_PLATFORM == 'jruby' || RUBY_VERSION[0,3] != '1.8'
          def timed_read_condition_wait(timeout)
            # This method not available in MRI 1.8
            @read_condition.wait(@outstanding_hash_mutex, timeout)
          end
        else
          require 'timeout'
          def timed_read_condition_wait(timeout)
            Timeout.timeout(timeout) do
              @read_condition.wait(@outstanding_hash_mutex)
            end
          rescue Timeout::Error => e
            return nil
          end
        end

      end
    end
  end
end
