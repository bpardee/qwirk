require 'rumx'

module Qwirk
  module Adapter
    module Base
      class WorkerConfig
        include ::Rumx::Bean

        # Make explicit the instance variables available to the derived adapter classes
        attr_reader        :adapter_factory, :name, :manager, :worker_class, :default_options, :options,
                           :queue_options, :response_options, :marshaler
        attr_accessor      :queue_name, :topic_name

        bean_attr_reader   :timer,     :bean,    'Track the times for this worker'
        bean_attr_accessor :log_times, :boolean, 'Log the times for this worker'

        # Define the default config values for the attributes all workers will share.  These will be sent as options to the constructor
        def self.initial_default_config
          {}
        end

        def self.default_marshal_sym
          :ruby
        end

        # By default, workers do not run in the same process as the publishers
        def self.in_process?(config)
          false
        end

        # Create new WorkerConfig to manage workers of a common class
        def initialize(adapter_factory, name, manager, worker_class, default_options, options)
          @adapter_factory  = adapter_factory
          @name             = name
          @manager          = manager
          @worker_class     = worker_class
          @default_options  = default_options.dup
          @options          = options.dup
          # First option is getting the queue or topic from the given options
          @queue_name       = options.delete(:queue_name)
          @topic_name       = !@queue_name && options.delete(:queue_name)
          # Second option is getting them from the default options
          @queue_name     ||= !@topic_name && default_options.delete(:queue_name)
          @topic_name     ||= !@queue_name && default_options.delete(:topic_name)
          # Third (and most likely) option is getting it based on the class topic or queue DSL or defaulting to the default queue
          @queue_name     ||= !@topic_name && worker_class.queue_name(@name)
          @topic_name     ||= !@queue_name && worker_class.topic_name

          if @queue_name
            more_queue_options = (default_options.delete(:queue_options) || {}).merge(options.delete(:queue_options) || {})
          else
            more_queue_options = (default_options.delete(:topic_options) || {}).merge(options.delete(:topic_options) || {})
          end
          @queue_options    = worker_class.queue_options.merge(more_queue_options)
          @response_options = @queue_options[:response] || {}

          # Defines how we will marshal the response
          marshal_sym       = (response_options[:marshal] || self.class.default_marshal_sym)
          @marshaler        = MarshalStrategy.find(marshal_sym)
          @log_times        = adapter_factory.log_times

          init

          #Qwirk.logger.debug { "options=#{options.inspect}" }
          default_options.each do |key, value|
            begin
              send(key.to_s+'=', value)
            rescue Exception => e
              # Let config_reader's set a default value
              begin
                instance_variable_set("@#{key}", value)
              rescue Exception => e
                Qwirk.logger.debug "DEBUG: During initialization of #{worker_class.name} config=#{@name}, default assignment of #{key}=#{value} was ignored"
              end
            end
          end
          # Run the specified options after the default options, so that codependant options don't get overwritten (like min_count/max_count)
          options.each do |key, value|
            begin
              send(key.to_s+'=', value)
            rescue Exception => e
              Qwirk.logger.debug "DEBUG: During initialization of #{worker_class.name} config=#{@name}, assignment of #{key}=#{value} was ignored"
            end
          end
        end

        # Allow extensions to initialize before setting the attributes
        def init
        end

        def stop
        end

        def join(timeout=nil)
        end

        def stopped?
          self.manager.stopped?
        end

        def worker_stopped(worker)
        end

        # Override rumx bean method
        def bean_attributes_changed
          super
          @manager.save_persist_state
        end

        def marshal_response(object)
          @marshaler.marshal(object)
        end

        def unmarshal_response(marshaled_object)
          @marshaler.unmarshal(marshaled_object)
        end

        def periodic_call(poll_time)
        end

        def to_s
          @name
        end
      end
    end
  end
end
