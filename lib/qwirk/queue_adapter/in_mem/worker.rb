# Handle Messaging and Queuing using JMS
module Qwirk
  module QueueAdapter
    module InMem
      class Worker
        attr_reader :stopped

        def initialize(name, marshaler, queue, queue_name, topic_name)
          @name       = name
          @marshaler  = marshaler
          @queue      = queue
          @queue_name = queue_name
          @topic_name = topic_name
        end

        def receive_message
          @queue.read(self)
        end

        def acknowledge_message(msg)
        end

        def send_response(original_message, marshaled_object)
          # We unmarshal so our workers get consistent messages regardless of the adapter
          do_send_response(original_message, @marshaler.unmarshal(marshaled_object))
        end

        def send_exception(original_message, e)
          # TODO: I think exceptions should be recreated fully so no need for marshal/unmarshal?
          do_send_response(original_message, Qwirk::RemoteException.new(e))
        end

        def message_to_object(msg)
          # The publisher has already unmarshaled the object to save hassle here.
          return msg
        end

        def handle_failure(message, fail_queue_name)
          # TODO: Mode for persisting to flat file?
          Qwirk.logger.warn("Dropping message that failed: #{message}")
        end

        def stop
          @stopped = true
        end

        def close
          return if @closed
          Qwirk.logger.debug { "Closing #{self}" }
          @closed = true
        end

        ## End of required override methods for worker adapter
        private

        def do_send_response(original_message, object)
          reply_queue = Factory.find_reply_queue(@queue_name, @topic_name, original_message.object_id)
          return unless reply_queue
          reply_queue.write_response(object, @name)
          return true
        end
      end
    end
  end
end
