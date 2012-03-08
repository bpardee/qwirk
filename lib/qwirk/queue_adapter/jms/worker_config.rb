# Handle Messaging and Queuing using JMS
module Qwirk
  module QueueAdapter
    module JMS
      class WorkerConfig
        include Rumx::Bean

        #bean_reader :queue_size,     :integer, 'Current count of messages in the queue'

        attr_reader :connection, :parent, :destination, :marshaler, :time_to_live, :persistent, :stopped

        def initialize(queue_adapter, parent, queue_name, topic_name, options, response_options)
          @connection   = queue_adapter.adapter_info
          @parent       = parent
          @destination  = {:queue_name => queue_name} if queue_name
          @destination  = {:topic_name => topic_name} if topic_name
          # Time in msec until the message gets discarded, should be more than the timeout on the requestor side
          @time_to_live = response_options[:time_to_live]
          @persistent   = response_options[:persistent]
        end

        # Default marshal type for the response
        def default_marshal_sym
          :ruby
        end

        def create_worker
          Worker.new(self)
        end

        def stop
          puts "in jms worker config stop"
          @stopped = true
        end
      end
    end
  end
end
