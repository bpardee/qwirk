require 'jms'

# Handle Messaging and Queuing
module Qwirk
  module QueueAdapter
    module JMS
      module Connection
        # Singleton-ize
        extend self

        # Initialize the messaging system and connection pool for this VM
        def init(config)
          @config = config
          @inited = true
          @log_times = config.delete(:log_times)
          # Default to true
          @log_times = true if @log_times.nil?

          @session_pool = connection.create_session_pool(@config)
          @connection = ::JMS::Connection.new(config)
          @connection.start

          at_exit do
            close
          end
        end

        def inited?
          @inited
        end

        def log_times?
          @log_times
        end

        # Create a session targeted for a consumer (producers should use the session_pool)
        def create_session
          connection.create_session(@config || {})
        end

        def session_pool
          @session_pool
        end

        def close
          return if @closed
          Qwirk.logger.info "Closing #{self.name}"
          @session_pool.close if @session_pool
          if @connection
            @connection.stop
            @connection.close
          end
          @closed = true
        end

        def connection
          raise "#{self.name} never had it's init method called" unless @connection
          @connection
        end
      end
    end
  end
end
