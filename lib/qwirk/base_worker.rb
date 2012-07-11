require 'rumx'

module Qwirk
  # TODO: Is this necessary anymore or just put in worker.rb?  Decide when flat file adapter is implemented.
  module BaseWorker

    attr_accessor :index, :thread, :config

    module ClassMethods
      def default_name
        name = self.name.sub(/Worker$/, '')
        name.sub(/::/, '_')
      end

      def bean_attrs
        @bean_attrs ||= []
      end

      #config_accessor :sleep_time, :float, 'Number of seconds to sleep between messages', 5
      def config_accessor(name, type, description, default_value=nil)
        self.bean_attrs << [:bean_attr_accessor, name, type, description, default_value]
      end

      def config_reader(name, type, description, default_value=nil)
        self.bean_attrs << [:bean_attr_reader, name, type, description, default_value]
      end

      def config_writer(name, type, description, default_value=nil)
        self.bean_attrs << [:bean_attr_writer, name, type, description, default_value]
      end

      def define_configs(configs)
        @configs = configs
      end

      # For each configuration of this worker, yield the name, extended_worker_config_class (the adapters
      # worker_config extended with this class's config attributes), and the default configuration values.
      def each_config(worker_config_class, &block)
        # Configs are either defined with a define_configs call or default to a single instance with default_config
        default_config = worker_config_class.initial_default_config
        extended_worker_config_class = Class.new(worker_config_class)
        self.bean_attrs.each do |args|
          attr_method, name, type, description, default_value = args
          extended_worker_config_class.send(attr_method, name, type, description, :config_item => true)
          default_config[name.to_sym] = default_value
        end
        if @configs
          @configs.each do |name, config|
            yield name, extended_worker_config_class, default_config.merge(config)
          end
        else
          yield default_name, extended_worker_config_class, default_config
        end
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
