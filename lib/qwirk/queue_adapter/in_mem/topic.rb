module Qwirk
  module QueueAdapter
    module InMem

      class Topic
        def initialize(name)
          @name            = name
          @outstanding_hash_mutex           = Mutex.new
          @worker_hash     = {}
          @stopped         = false
        end

        def get_worker_queue(worker_name, queue_max_size)
          @outstanding_hash_mutex.synchronize do
            queue = @worker_hash[worker_name] ||= Queue.new("#{@name}:#{worker_name}")
            queue.max_size = queue_max_size
            return queue
          end
        end

        def stop
          @stopped = true
          @worker_hash.each_value do |queue|
            queue.stop
          end
        end

        def read
          raise "topic should not have been read for #{name}"
        end

        def write(obj, response_options)
          @outstanding_hash_mutex.synchronize do
            @worker_hash.each_value do |queue|
              if !@stopped
                queue.write(obj, response_options)
              end
            end
          end
        end

        def to_s
          "topic:#{@name}"
        end
      end
    end
  end
end
