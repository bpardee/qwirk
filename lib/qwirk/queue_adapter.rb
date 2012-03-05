require 'qwirk/queue_adapter/jms'
require 'qwirk/queue_adapter/in_mem'

module Qwirk

  # Defines the queuing strategy.  Currently, only JMS and InMem.
  module QueueAdapter

    @publisher_klass     = nil
    @worker_config_klass = nil

    def self.define(publisher_klass, worker_config_klass)
      @publisher_klass, @worker_config_klass = publisher_klass, worker_config_klass
    end

    def self.set(type)
      case type
        when :jms
          @publisher_klass     = JMS::Publisher
          @worker_config_klass = JMS::WorkerConfig
        when :in_mem
          @publisher_klass     = InMem::Publisher
          @worker_config_klass = InMem::WorkerConfig
        else
          raise "Unknown QueueAdapter type=#{type}"
      end
    end

    def self.create_publisher(queue_name, topic_name, options, response_options)
      unless @publisher_klass
        if QueueAdapter::JMS::Connection.inited?
          @publisher_klass = QueueAdapter::JMS::Publisher
        else
          @publisher_klass = QueueAdapter::InMem::Publisher
        end
      end
      return @publisher_klass.new(queue_name, topic_name, options, response_options)
    end

    def self.create_worker_config(worker_config, queue_name, topic_name, options, response_options)
      unless @worker_config_klass
        if QueueAdapter::JMS::Connection.inited?
          @worker_config_klass = JMS::WorkerConfig
        else
          @worker_config_klass = InMem::WorkerConfig
        end
      end
      return @worker_config_klass.new(worker_config, queue_name, topic_name, options, response_options)
    end

    # Ripped off from ActiveSupport
    def underscore(camel_cased_word)
      word = camel_cased_word.to_s.dup
      word.gsub!(/::/, '/')
      word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end
  end
end
