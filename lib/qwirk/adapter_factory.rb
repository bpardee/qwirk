module Qwirk

  # Defines the queuing adapter.  Currently, only JMS and InMem.
  class AdapterFactory
    include Rumx::Bean

    attr_reader :key, :config, :log_times, :adapter_info, :worker_config_class, :manager

    def initialize(key, config)
      @key       = key
      @config    = config.dup
      @log_times = config.delete(:log_times)

      adapter = config.delete(:adapter)
      raise "No adapter definition" unless adapter
      namespace = Qwirk::Adapter.const_get(adapter)
      @adapter_info = nil
      if namespace.respond_to?(:init)
        @adapter_info = namespace.init(config)
      end
      @publisher_class     = namespace.const_get('Publisher')
      @worker_config_class = namespace.const_get('WorkerConfig')
    end

    def create_publisher(options={})
      @publisher_parent ||= Rumx::Beans::Folder.new
      publisher = Publisher.new(self, @config.merge(options))
      @publisher_parent.bean_add_child(publisher.to_s, publisher)
      return publisher
    end

    def create_manager(options={})
      @manager = Manager.new(self, @config.merge(options))
      bean_add_child(:Workers, @manager)
      return @manager
    end

    def create_publisher_impl(queue_name, topic_name, options, response_options)
      @publisher_class.new(self, queue_name, topic_name, options, response_options)
    end
  end
end
