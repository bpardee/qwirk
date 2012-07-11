module Qwirk
  module Adapter
    module InMem
      module Factory
        class << self
          def init
            @queue_hash             = {}
            @topic_hash             = {}
            @queue_hash_mutex       = Mutex.new
            @topic_hash_mutex       = Mutex.new
          end

          def get_worker_queue(worker_name, queue_name, topic_name, queue_max_size)
            if queue_name
              @queue_hash_mutex.synchronize do
                queue = @queue_hash[queue_name] ||= Queue.new(queue_name)
                queue.max_size = queue_max_size
                return queue
              end
            else
              @topic_hash_mutex.synchronize do
                topic = @topic_hash[topic_name] ||= Topic.new(topic_name)
                return topic.get_worker_queue(worker_name, queue_max_size)
              end
            end
          end

          def get_publisher_queue(queue_name, topic_name)
            if queue_name
              @queue_hash_mutex.synchronize do
                return @queue_hash[queue_name] ||= Queue.new(queue_name)
              end
            else
              @topic_hash_mutex.synchronize do
                return @topic_hash[topic_name] ||= Topic.new(topic_name)
              end
            end
          end
        end
      end

      Factory.init
    end
  end
end
