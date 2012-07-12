# Handle Messaging and Queuing using JMS
module Qwirk
  module Adapter
    module JMS
      class Consumer
        attr_reader :stopped

        def initialize(connection, options)
          @options = options
          @session = connection.create_session
          @consumer = @session.consumer(@options)
          @session.start
          @stopped = false
        end

        def receive
          @message = @consumer.receive
          return nil unless @message
          return Util.parse_response(@message)
        end

        def acknowledge_message
          @message.acknowledge
        end

        def stop
          return if @stopped
          Qwirk.logger.info "Stopping consumer for #{@options.inspect}"
          # Don't clobber the session before a reply
          @consumer.close if @consumer
          @session.close if @session
          @stopped = true
        end
      end
    end
  end
end
