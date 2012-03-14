module Qwirk

  # Defines the queuing strategy.  Currently, only JMS and InMem.
  class Adapter
    include Rumx::Bean

    attr_reader :config, :log_times, :adapter_info

    def initialize(config)
      @config = config.dup
      @log_times = config.delete(:log_times)

      adapter = config.delete(:adapter)
      raise "No adapter definition" unless adapter
      namespace = Qwirk::QueueAdapter.const_get(adapter)
      @adapter_info = nil
      if namespace.respond_to?(:init)
        @adapter_info = namespace.init(config)
      end
      @publisher_klass     = namespace.const_get('Publisher')
      @worker_config_klass = namespace.const_get('WorkerConfig')
    end

    def create_publisher(options={})
      Publisher.new(self, options)
    end

    def create_manager(options={})
      Manager.new(self, options)
    end

    def create_adapter_publisher(queue_name, topic_name, options, response_options)
      @publisher_klass.new(self, queue_name, topic_name, options, response_options)
    end

    def create_adapter_worker_config(parent, queue_name, topic_name, options, response_options)
      @worker_config_klass.new(self, parent, queue_name, topic_name, options, response_options)
    end

    # Ripped off from ActiveSupport
    #def underscore(camel_cased_word)
    #  word = camel_cased_word.to_s.dup
    #  word.gsub!(/::/, '/')
    #  word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    #  word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    #  word.tr!("-", "_")
    #  word.downcase!
    #  word
    #end
  end
end
