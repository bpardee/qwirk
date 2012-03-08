module Qwirk
  module QueueAdapter
    module ActiveMQ
      class Publisher < JMS::Publisher
        def initialize(queue_adapter, queue_name, topic_name, options, response_options)
          topic_name = "VirtualTopic.#{topic_name}" if topic_name
          super(queue_adapter, queue_name, topic_name, options, response_options)
        end
      end
    end
  end
end
