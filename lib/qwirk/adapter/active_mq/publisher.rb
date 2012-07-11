module Qwirk
  module Adapter
    module ActiveMQ
      class Publisher < JMS::Publisher
        def initialize(adapter_factory, queue_name, topic_name, options, response_options)
          topic_name = "VirtualTopic.#{topic_name}" if topic_name
          super(adapter_factory, queue_name, topic_name, options, response_options)
        end
      end
    end
  end
end
