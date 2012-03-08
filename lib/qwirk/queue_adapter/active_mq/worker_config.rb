# Handle Messaging and Queuing using ActiveMQ
module Qwirk
  module QueueAdapter
    module ActiveMQ
      class WorkerConfig < JMS::WorkerConfig
        def initialize(queue_adapter, parent, queue_name, topic_name, options, response_options)
          if topic_name
            queue_name = "Consumer.#{parent.name}.VirtualTopic.#{topic_name}"
            topic_name = nil
          end
          super(queue_adapter, parent, queue_name, topic_name, options, response_options)
        end
      end
    end
  end
end
