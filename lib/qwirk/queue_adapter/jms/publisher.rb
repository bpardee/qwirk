# Handle Messaging and Queuing using JMS
module Qwirk
  module QueueAdapter
    module JMS
      class Publisher

        #attr_reader :persistent, :marshaler, :reply_queue

        def initialize(queue_name, topic_name, options, response_options)
          response_options         ||= {}
          @dest_options              = {:queue_name => queue_name} if queue_name
          @dest_options              = {:topic_name => topic_name} if topic_name
          @persistent_sym            = options[:persistent] ? :persistent : :non_persistent
          @time_to_live              = options[:time_to_live]
          @response_time_to_live_str = response_options[:time_to_live] && response_options[:time_to_live].to_s
          @response_persistent_str   = nil
          @response_persistent_str   = (!!response_options[:persistent]).to_s unless response_options[:persistent].nil?

          # TODO: Use sync attribute so this queue isn't constantly created.
          reply_queue_name = response_options[:queue_name] || :temporary
          if response_options
            Connection.session_pool.session do |session|
              @reply_queue = session.create_destination(:queue_name => reply_queue_name)
            end
          end
        end

        def default_marshal_sym
          :ruby
        end

        # Publish the given object and return the message_id.
        def publish(marshaled_object, marshal_sym, marshal_type, task_id, props)
          message = nil
          Connection.session_pool.producer(@dest_options) do |session, producer|
            producer.time_to_live                  = @time_to_live if @time_to_live
            producer.delivery_mode_sym             = @persistent_sym
            message = JMS.create_message(session, marshaled_object, marshal_type)
            message.jms_reply_to                   = @reply_queue if @reply_queue
            message['qwirk:marshal']               = marshal_sym.to_s
            message['qwirk:response:time_to_live'] = @response_time_to_live_str if @response_time_to_live_str
            message['qwirk:response:persistent']   = @response_persistent_str unless @response_persistent_str.nil?
            message['qwirk:task_id']               = task_id if task_id
            props.each do |key, value|
              message.send("#{key}=", value)
            end
            producer.send(message)
          end
          return message.jms_message_id
        end

        # Creates a block for reading the responses for a given message_id.  The block will be passed an object
        # that responds to read(timeout) with a [message, worker_name] pair or nil if no message is read.
        # This is used in the RPC mechanism where a publish might wait for 1 or more workers to respond.
        def with_response(message_id, &block)
          raise "Invalid call to read_response for #{@publisher}, not setup for responding" unless @reply_queue
          options = { :destination => @reply_queue, :selector => "JMSCorrelationID = '#{message_id}'" }
          Connection.session_pool.consumer(options) do |session, consumer|
            yield MyConsumer.new(consumer)
          end
        end

        # Creates an consumer for reading responses for a given task_id.  It will return an object that responds_to
        # read_response which will return a [message_id, response object] and acknowledge_message which will acknowledge the
        # last message read.  It should also respond to close which will interrupt
        # any read_response calls causing it to return nil.
        def create_task_consumer(task_id)
          return MyTaskConsumer.new(@reply_queue, task_id)
        end

        #######
        private
        #######

        class MyConsumer
          attr_reader :worker_name

          def initialize(consumer)
            @consumer = consumer
          end

          def read_response(timeout)
            msec = (timeout * 1000).to_i
            if msec > 100
              message = @consumer.receive(msec)
            else
              #message = @consumer.receive_no_wait
              message = @consumer.receive(100)
            end
            return nil unless message
            message.acknowledge
            return [JMS.parse_response(message), message['qwirk:worker']]
          end
        end

        class MyTaskConsumer
          def initialize(reply_queue, task_id)
            options = { :destination => reply_queue, :selector => "qwirk:task_id = '#{task_id}'" }
            @session = Connection.create_session
            @consumer = @session.consumer(options)
            @session.start
            @closed = false
          end

          def read_response
            @message = @consumer.receive
            return nil unless @message
            return [message.jms_correlation_id, JMS.parse_respone(message)]
          end

          def acknowledge_message
            @message.acknowledge
          end

          def close
            return if @closed
            Qwirk.logger.info "Closing Task worker #{@worker_config.parent.name}"
            # Don't clobber the session before a reply
            @consumer.close if @consumer
            @session.close if @session
            @closed = true
          end
        end
      end
    end
  end
end
