require 'yaml'

require 'qwirk/adapter/jms/connection'
require 'qwirk/adapter/jms/publisher'
require 'qwirk/adapter/jms/worker_config'
require 'qwirk/adapter/jms/worker'

module Qwirk
  module Adapter
    module JMS
      def self.init(config)
        Connection.new(config)
      end
    end
  end
end
