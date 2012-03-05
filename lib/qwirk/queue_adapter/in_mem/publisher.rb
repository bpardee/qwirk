
module Qwirk
  module QueueAdapter
    module InMem
      class Publisher

        def initialize(queue_name, topic_name, options, response_options)
          @queue_name, @topic_name, @options, @response_options = queue_name, topic_name, options, response_options
          @queue = Factory.get_publisher_queue(queue_name, topic_name)
        end

        def default_marshal_sym
          :none
        end

        # Publish the given object and return the message_id.
        def publish(marshaled_object, marshal_sym, marshal_type, task_id, props)
          # Since we're in-memory, we'll just unmarshal the object so there is less info to carry around
          marshaler = MarshalStrategy.find(marshal_sym)
          object = marshaler.unmarshal(marshaled_object)
          message_id = object.object_id
          Factory.create_reply_queue(@queue_name, @topic_name, message_id, @response_options[:total_allowed_reply_queues] || 100) if @response_options
          @queue.write(object, @response_options)
          return message_id
        end

        # Creates a block for reading the responses for a given message_id.  The block will be passed an object
        # that responds to read(timeout) with a [message, worker_name] pair or nil if no message is read
        def with_response(message_id, &block)
          reply_queue = Factory.find_reply_queue(@queue_name, @topic_name, message_id)
          raise "Could not find reply_queue for #{@queue} message_id=#{message_id}" unless reply_queue
          yield reply_queue
          Factory.delete_reply_queue(@queue_name, @topic_name, message_id)
        end

        # Creates an consumer for reading responses for a given task_id.  It will return an object that responds_to
        # read_response which will return a [message_id, response object] and acknowledge_message which will acknowledge the
        # last message read.  It should also respond to close which will interrupt
        # any read_response calls causing it to return nil.
        def create_task_consumer(task_id)
          return MyTaskConsumer.new(@reply_queue, task_id)
        end
      end
    end
  end
end
