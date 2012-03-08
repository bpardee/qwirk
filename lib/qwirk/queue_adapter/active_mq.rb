require 'activemq'
require 'qwirk/queue_adapter/active_mq/publisher'
require 'qwirk/queue_adapter/active_mq/worker_config'

module Qwirk
  module QueueAdapter
    module ActiveMQ
      def self.init(config)
        JMS.init(config)
      end
    end
  end
end
