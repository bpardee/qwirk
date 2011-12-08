require 'rumx'

module ModernTimes
  # TODO: Is this necessary anymore or just put in worker.rb?  Decide when flat file queue_adapter is implemented.
  module BaseWorker

    attr_accessor :index, :thread, :config

    module ClassMethods
      def default_name
        name = self.name.sub(/Worker$/, '')
        name.sub(/::/, '_')
      end

      # Dynamic class create form WorkerConfig and extended through config_accessor, etc calls that will be defined in the worker
      def config_class
        @config_class ||= Class.new(WorkerConfig)
      end

      # Default values for all the config attributes
      def default_config
        @default_config ||= WorkerConfig.initial_default_config
      end

      #config_accessor :sleep_time, :float, 'Number of seconds to sleep between messages', 5
      def config_accessor(name, type, description, default_value=nil)
        make_bean_attr(:bean_attr_accessor, name, type, description, default_value)
      end

      def config_reader(name, type, description, default_value=nil)
        make_bean_attr(:bean_attr_reader, name, type, description, default_value)
      end

      def config_writer(name, type, description, default_value=nil)
        make_bean_attr(:bean_attr_writer, name, type, description, default_value)
      end

      def define_configs(configs)
        @configs = configs
      end

      def each_config(&block)
        # Configs are either defined with a define_configs call or default to a single instance with default_config
        if @configs
          @configs.each do |name, config|
            yield name, default_config.merge(config)
          end
        else
          yield default_name, default_config
        end
      end

      #######
      private
      #######

      def make_bean_attr(attr_method, name, type, description, default_value)
        config_class.send(attr_method, name, type, description, :config_item => true)
        default_config[name.to_sym] = default_value
      end
    end

    def self.included(base)
      Rumx::Bean.included(base)
      base.extend(ClassMethods)
      if base.kind_of?(Class)
        @worker_classes ||= []
        @worker_classes << base unless @worker_classes.include?(base)
      end
    end

    def self.worker_classes
      @worker_classes ||= []
    end

    def start
      raise "Need to override start method in #{self.class.name}"
    end

    def stop
      raise "Need to override stop method in #{self.class.name}"
    end

    def join
      thread.join
    end

    def status
      raise "Need to override status method in #{self.class.name}"
    end

    def to_s
      "#{config.name}:#{index}"
    end
  end
end
