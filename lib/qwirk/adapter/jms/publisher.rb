# Handle Messaging and Queuing using JMS
module Qwirk
  module Adapter
    module JMS
      class Publisher

        #attr_reader :persistent, :marshaler, :reply_queue

        def initialize(adapter_factory, queue_name, topic_name, options, response_options)
          @connection                = adapter_factory.adapter_info
          response_options         ||= {}
          @dest_options              = {:queue_name => queue_name} if queue_name
          @dest_options              = {:topic_name => topic_name} if topic_name
          @persistent_sym            = options[:persistent] ? :persistent : :non_persistent
          @time_to_live              = options[:time_to_live]
          @response_time_to_live_str = response_options[:time_to_live] && response_options[:time_to_live].to_s
          @response_persistent_str   = nil
          @response_persistent_str   = (!!response_options[:persistent]).to_s unless response_options[:persistent].nil?

          @connection.session_pool.session do |session|
            # TODO: Use sync attribute so these queues aren't constantly created.
            @dest_queue = session.create_destination(@dest_options)
            if response_options
              reply_queue_name = response_options[:queue_name] || :temporary
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
          @connection.session_pool.producer(:destination => @dest_queue) do |session, producer|
            producer.time_to_live                  = @time_to_live if @time_to_live
            producer.delivery_mode_sym             = @persistent_sym
            message = Util.create_message(session, marshaled_object, marshaler.marshal_type)
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
          raise "Invalid call to with_response for #{self}, not setup for responding" unless @reply_queue
          options = { :destination => @reply_queue, :selector => "JMSCorrelationID = '#{message_id}'" }
          @connection.session_pool.consumer(options) do |session, consumer|
            yield MyConsumer.new(consumer)
          end
        end

        # See Qwirk::Publisher#create_task_consumer for the requirements for this method.
        def create_producer_consumer_pair(task_id, marshaler)
          producer = MyTaskProducer.new(self, @reply_queue, task_id, marshaler)
          consumer = Consumer.new(@connection, :destination => reply_queue, :selector => "QwirkTaskID = '#{task_id}'")
          return producer, consumer
        end

        def create_fail_producer_consumer_pair(task_id, marshaler)
          fail_queue = nil
          @connection.session_pool.session do |session|
            fail_queue = session.create_destination(:queue_name => :temporary)
          end
          producer = MyTaskProducer.new(self, fail_queue, task_id, marshaler)
          consumer = Consumer.new(@connection, :destination => reply_queue, :selector => "QwirkTaskID = '#{task_id}'")
          return producer, consumer
        end

        def to_s
          "Publisher: #{@dest_options.inspect}"
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
            return [message.jms_correlation_id, Util.parse_response(message), message['qwirk:worker']]
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
      end
    end
  end
end
