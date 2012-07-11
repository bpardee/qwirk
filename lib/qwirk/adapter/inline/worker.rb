# Handle Messaging and Queuing using JMS
module Qwirk
  module Adapter
    module Inline
      class Worker

        attr_accessor :response_handle

        def initialize(name, marshaler)
          @name       = name
          @marshaler  = marshaler
        end

        # We never call worker.start so this method is unnecessary
        def receive_message
        end

        # We never call worker.start so this method is unnecessary
        def acknowledge_message(message)
        end

        def send_response(original_message, marshaled_object)
          # We unmarshal so our workers get consistent messages regardless of the adapter
          do_send_response(original_message, @marshaler.unmarshal(marshaled_object))
        end

        def send_exception(original_message, e)
          do_send_response(original_message, Qwirk::RemoteException.new(e))
        end

        def message_to_object(msg)
          # The publisher has already unmarshaled the object to save hassle here.
          return msg
        end

        def handle_failure(message, exception, fail_queue_name)
          Qwirk.logger.warn("Dropping message that failed: #{message}")
        end

        def stop
        end

        ## End of required override methods for worker impl
        private

        def do_send_response(original_message, object)
          puts "Returning #{object} to queue #{@response_handle}"
          return false unless @response_handle
          @response_handle.add(original_message.object_id, object, @name)
          return true
        end
      end
    end
  end
end
