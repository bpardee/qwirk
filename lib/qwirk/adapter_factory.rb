module Qwirk

  # Defines the queuing adapter.  Currently, only JMS and InMemory.
  class AdapterFactory
    include Rumx::Bean

    attr_reader :key, :config, :log_times, :adapter_info, :worker_config_class, :manager

    @@adapter_hash = {}

    # Register an adapter by passing in a publisher_class, a worker_config_class and optionally a code block.
    # The code block will expect a config object as it's argument and will return connection information
    # or any other client_information required for this adapter.
    def self.register(key, publisher_class, worker_config_class, &block)
      @@adapter_hash[key] = [publisher_class, worker_config_class, block]
    end

    def initialize(key, config)
      @key       = key
      @config    = config.dup
      @log_times = config.delete(:log_times)

      key = config.delete(:adapter)
      raise "No adapter definition config=#{config.inspect}" unless key
      key = key.to_sym
      @publisher_class, @worker_config_class, block = @@adapter_hash[key]
      raise "No adapter matching #{key}" unless @publisher_class
      @adapter_info = block.call(config) if block
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

    def in_process?
      @worker_config_class.in_process?(@config)
    end
  end
end
