require 'jms'

# Handle Messaging and Queuing
module Qwirk
  module Adapter
    module JMS
      class Connection
        # Initialize the messaging system and connection pool for this VM
        def initialize(config)
          @config = config
          @connection = ::JMS::Connection.new(config)
          @session_pool = @connection.create_session_pool(@config)
          @connection.start

          at_exit do
            close
          end
        end

        # Create a session targeted for a consumer (producers should use the session_pool)
        def create_session
          @connection.create_session(@config || {})
        end

        def session_pool
          @session_pool
        end

        def close
          return if @closed
          Qwirk.logger.info "Closing JMS connection"
          @session_pool.close if @session_pool
          if @connection
            @connection.stop
            @connection.close
          end
          @closed = true
        end
      end
    end
  end
end
