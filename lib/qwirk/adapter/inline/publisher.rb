module Qwirk
  module Adapter
    module Inline
      class Publisher

        class MyResponseHandle
          def initialize
            @responses = []
          end

          def add(original_message_id, response_message, worker_name)
            @responses << [original_message_id, response_message, worker_name]
          end

          # We're inline so we either have a response or not (not is interpreted as a timeout)
          def timeout_read(timeout)
            @responses.pop
          end
        end

        def initialize(adapter_factory, queue_name, topic_name, options, response_options)
          @adapter_factory, @queue_name, @topic_name, @options, @response_options = adapter_factory, queue_name, topic_name, options, response_options
        end

        def default_marshal_sym
          :none
        end

        # Publish the given object and return the reply_queue as the adapter_info.
        def publish(marshaled_object, marshaler, task_id, props)
          response_handle = @response_options ? MyResponseHandle.new : nil
          # Since we're inline, we'll just unmarshal the object so there is less info to carry around
          object = marshaler.unmarshal(marshaled_object)
          if manager = @adapter_factory.manager
            @message_handled = false
            manager.worker_configs.each do |worker_config|
              if worker_config.active
                if @queue_name && @queue_name == worker_config.queue_name
                  run_worker(worker_config, object, response_handle)
                  @message_handled = true
                  break
                elsif @topic_name && @topic_name == worker_config.topic_name
                  run_worker(worker_config, object, response_handle)
                  @message_handled = true
                end
              end
            end
            if !@message_handled && !@no_message_handled_warning
              Qwirk.logger.warn("Publish message #{object.inspect} being dropped as no Qwirk worker has been configured to handle it")
              @no_message_handled_warning = true
            end
          elsif !@no_manager_warning
            Qwirk.logger.warn("Publish message #{object.inspect} being dropped as no Qwirk manager has been configured for #{@adapter_factory.key}")
            @no_manager_warning = true
          end
          return response_handle
        end

        # See Qwirk::PublishHandle#read_response for the requirements for this method.
        def with_response(response_handle, &block)
          raise "Could not find response_handle" unless response_handle
          yield response_handle
        end

        # See Qwirk::Publisher#create_producer_consumer_pair for the requirements for this method
        def create_producer_consumer_pair(task_id, marshaler)
          # TBD
        end

        def create_fail_producer_consumer_pair(task_id, marshaler)
          # TBD
        end

        #######
        private
        #######
        def run_worker(worker_config, object, response_handle)
          worker = worker_config.worker_class.new
          worker.init(0, worker_config)
          worker.impl.response_handle = response_handle
          worker.on_message(object)
        end
      end
    end
  end
end
