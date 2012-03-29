# Handle Messaging and Queuing using JMS
module Qwirk
  module QueueAdapter
    module JMS
      class Publisher

        #attr_reader :persistent, :marshaler, :reply_queue

        def initialize(queue_adapter, queue_name, topic_name, options, response_options)
          @connection                = queue_adapter.adapter_info
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
            @connection.session_pool.session do |session|
              @reply_queue = session.create_destination(:queue_name => reply_queue_name)
            end
          end
        end

        def default_marshal_sym
          :ruby
        end

        # Publish the given object and return the message_id.
        # TODO: Too hackish to include task_id in here, think of a better solution
        def publish(marshaled_object, marshaler, task_id, props)
          message = nil
          @connection.session_pool.producer(@dest_options) do |session, producer|
            producer.time_to_live                  = @time_to_live if @time_to_live
            producer.delivery_mode_sym             = @persistent_sym
            message = JMS.create_message(session, marshaled_object, marshaler.marshal_type)
            message.jms_reply_to                   = @reply_queue if @reply_queue
            message['qwirk:marshal']               = marshaler.to_sym.to_s
            message['qwirk:response:time_to_live'] = @response_time_to_live_str if @response_time_to_live_str
            message['qwirk:response:persistent']   = @response_persistent_str unless @response_persistent_str.nil?
            message['QwirkTaskID']                 = task_id if task_id
            props.each do |key, value|
              message.send("#{key}=", value)
            end
            producer.send(message)
          end
          # Return the adapter_info which for JMS is the message_id.  This value will be sent to with_response below.
          return message.jms_message_id
        end

        # See Qwirk::PublishHandle#read_response for the requirements for this method.
        def with_response(message_id, &block)
          raise "Invalid call to with_response for publisher to #{@dest_options.inspect}, not setup for responding" unless @reply_queue
          options = { :destination => @reply_queue, :selector => "JMSCorrelationID = '#{message_id}'" }
          @connection.session_pool.consumer(options) do |session, consumer|
            yield MyConsumer.new(consumer)
          end
        end

        # See Qwirk::Publisher#create_task_consumer for the requirements for this method.
        def create_producer_consumer_pair(task_id, marshaler)
          producer = MyTaskProducer.new(self, @reply_queue, task_id, marshaler)
          consumer = MyTaskConsumer.new(@connection, @reply_queue, task_id)
          return producer, consumer
        end

        def create_fail_producer_consumer_pair(task_id, marshaler)
          fail_queue = nil
          @connection.session_pool.session do |session|
            fail_queue = session.create_destination(:queue_name => :temporary)
          end
          producer = MyTaskProducer.new(self, fail_queue, task_id, marshaler)
          consumer = MyTaskConsumer.new(@connection, fail_queue, task_id)
          return producer, consumer
        end

        #######
        private
        #######

        class MyConsumer
          attr_reader :worker_name

          def initialize(consumer)
            @consumer = consumer
          end

          def timeout_read(timeout)
            msec = (timeout * 1000).to_i
            if msec > 100
              message = @consumer.receive(msec)
            else
              #message = @consumer.receive_no_wait
              message = @consumer.receive(100)
            end
            return nil unless message
            message.acknowledge
            return [message.jms_correlation_id, JMS.parse_response(message), message['qwirk:worker']]
          end
        end

        class MyTaskProducer
          def initialize(publisher, reply_queue, task_id, marshaler)
            @publisher   = publisher
            @reply_queue = reply_queue
            @task_id     = task_id
            @marshaler   = marshaler
          end

          def send(marshaled_object)
            @publisher.publish(marshaled_object, @marshaler, @task_id, {})
          end
        end

        class MyTaskConsumer
          attr_reader :stopped

          def initialize(connection, reply_queue, task_id)
            @options = { :destination => reply_queue, :selector => "QwirkTaskID = '#{task_id}'" }
            @session = connection.create_session
            @consumer = @session.consumer(@options)
            @session.start
            @stopped = false
          end

          def receive
            @message = @consumer.receive
            return nil unless @message
            return [@message.jms_correlation_id, JMS.parse_response(@message)]
          end

          def acknowledge_message
            @message.acknowledge
          end

          def stop
            return if @stopped
            Qwirk.logger.info "Stopping Task consumer for #{@options.inspect}"
            # Don't clobber the session before a reply
            @consumer.close if @consumer
            @session.close if @session
            @stopped = true
          end
        end
      end
    end
  end
end
