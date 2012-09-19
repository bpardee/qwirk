module Qwirk
  module Adapter
    module InMemory

      class Topic
        def initialize(name)
          @name              = name
          @worker_hash_mutex = Mutex.new
          @worker_hash       = {}
        end

        def get_worker_queue(worker_name, queue_max_size)
          @worker_hash_mutex.synchronize do
            queue = @worker_hash[worker_name] ||= Queue.new("#{@name}:#{worker_name}")
            queue.max_size = queue_max_size
            return queue
          end
        end

        def stop
          @worker_hash_mutex.synchronize do
            @worker_hash.each_value do |queue|
              queue.stop
            end
          end
        end

        def read
          raise "topic should not have been read for #{name}"
        end

        def write(obj)
          @worker_hash_mutex.synchronize do
            @worker_hash.each_value do |queue|
              queue.write(obj)
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
