# Handle Messaging and Queuing using ActiveMQ
module Qwirk
  module Adapter
    module ActiveMQ
      class WorkerConfig < JMS::WorkerConfig
        def initialize(adapter_factory, parent, queue_name, topic_name, options, response_options)
          if topic_name
            queue_name = "Consumer.#{parent.name}.VirtualTopic.#{topic_name}"
            topic_name = nil
          end
          super(adapter_factory, parent, queue_name, topic_name, options, response_options)
        end
      end
    end
  end
end
