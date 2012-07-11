require 'activemq'
require 'qwirk/adapter/active_mq/publisher'
require 'qwirk/adapter/active_mq/worker_config'

module Qwirk
  module Adapter
    module ActiveMQ
      def self.init(config)
        JMS.init(config)
      end
    end
  end
end
