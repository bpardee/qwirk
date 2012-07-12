# Handle Messaging and Queuing using JMS
module Qwirk
  module Adapter
    module JMS
      class WorkerConfig < Qwirk::Adapter::Base::ExpandingWorkerConfig

        #bean_reader :queue_size,     :integer, 'Current count of messages in the queue', :config_item => true

        attr_reader :connection, :destination, :time_to_live, :persistent

        def self.default_marshal_sym
          :ruby
        end

        def init
          super
          @connection   = self.adapter_factory.adapter_info
          @destination  = {:queue_name => self.queue_name} if self.queue_name
          @destination  = {:topic_name => self.topic_name} if self.topic_name
          # Time in msec until the message gets discarded, should be more than the timeout on the requestor side
          @time_to_live = self.response_options[:time_to_live]
          @persistent   = self.response_options[:persistent]
        end

        def create_worker
          Worker.new(self)
        end
      end
    end
  end
end
