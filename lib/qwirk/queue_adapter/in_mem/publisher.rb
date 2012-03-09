module Qwirk
  module QueueAdapter
    module InMem
      class Publisher

        def initialize(queue_adapter, queue_name, topic_name, options, response_options)
          @queue_name, @topic_name, @options, @response_options = queue_name, topic_name, options, response_options
          @queue = Factory.get_publisher_queue(queue_name, topic_name)
        end

        def default_marshal_sym
          :none
        end

        # Publish the given object and return the reply_queue as the adapter_info.
        def publish(marshaled_object, marshaler, task_id, props)
          # Since we're in-memory, we'll just unmarshal the object so there is less info to carry around
          object = marshaler.unmarshal(marshaled_object)
          reply_queue = nil
          if @response_options
            reply_queue = ReplyQueue.new("#{@queue}:#{object.to_s}")
          end
          @queue.write([object, reply_queue])
          # Return the object to get sent to with_response below.
          return reply_queue
        end

        # See Qwirk::PublishHandle#read_response for the requirements for this method.
        def with_response(reply_queue, &block)
          raise "Could not find reply_queue for #{@queue}" unless reply_queue
          yield reply_queue
        end

        # See Qwirk::Publisher#create_producer_consumer_pair for the requirements for this method
        def create_producer_consumer_pair(task_id, marshaler)
          consumer_queue = Queue.new("#{@queue}:#{task_id}")
          consumer_queue.max_size = @response_options[:queue_max_size] || 100
          producer = MyTaskProducer.new(@queue, consumer_queue, marshaler, @response_options)
          consumer  = MyTaskConsumer.new(@queue, consumer_queue)
          return producer, consumer
        end

        private

        class MyTaskProducer
          def initialize(producer_queue, consumer_queue, marshaler, response_options)
            @producer_queue   = producer_queue
            @consumer_queue   = consumer_queue
            @marshaler        = marshaler
            @response_options = response_options
          end

          def send(marshaled_object)
            object = @marshaler.unmarshal(marshaled_object)
            @producer_queue.write([object, @consumer_queue])
            return object.object_id
          end
        end

        class MyTaskConsumer
          attr_reader :stopped

          def initialize(producer_queue, consumer_queue)
            @producer_queue = producer_queue
            @consumer_queue = consumer_queue
            @stopped = false
          end

          def receive
            message_id, response, worker_name = @consumer_queue.read(self)
            return nil unless response
            return [message_id, response]
          end

          def acknowledge_message
          end

          def stop
            return if @stopped
            Qwirk.logger.info "Stopping Task worker #{@consumer_queue}"
            # Don't clobber the session before a reply
            @producer_queue.interrupt_read
            @stopped = true
          end
        end
      end
    end
  end
end
