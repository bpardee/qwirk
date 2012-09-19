require 'rubygems'
require 'rumx'
require 'qwirk/loggable'

module Qwirk
  extend Qwirk::Loggable

  DEFAULT_NAME = 'Qwirk'

  @@config      = nil
  @@environment = nil
  @@hash        = {}

  class MyBean
    include Rumx::Bean

    # These are actually AdapterFactory's but presenting as adapters to the user.
    bean_attr_reader :adapters,  :hash, 'Adapters', :hash_type => :bean

    def initialize(hash)
      @adapters = hash
    end
  end

  def self.config=(config)
    #if config.has_key?(:adapter)
    @@config = config
    Rumx::Bean.root.bean_add_child(DEFAULT_NAME, MyBean.new(@@hash))
  end

  def self.environment=(environment)
    @@environment = environment
  end

  def self.config_file=(config_file)
    raise "No such file: #{config_file}" unless File.exist?(config_file)
    config = YAML.load(ERB.new(File.read(config_file), nil, '-').result(binding))
    config = config[@@environment] if config && @@environment
    if config.has_key?(:adapter) || config.has_key?('adapter')
      # Single level, one default adapter
      @@config = {'default' => config}
    else
      @@config = config
    end
  end

  def self.[](adapter_key)
    if @@config.nil?
      if defined?(Rails)
        # Allow user to use a different adapter w/o modifying qwirk.yml which could be checked in and hose other users
        self.environment = ENV['QWIRK_ENV'] || Rails.env
        self.config_file = Rails.root.join('config', 'qwirk.yml')
        Manager.default_options = {
            :persist_file    => Rails.root.join('log',    'qwirk_persist.yml'),
            :worker_file     => Rails.root.join('config', 'qwirk_workers.yml'),
            :stop_on_signal  => true,
            :env             => @@environment,
        }
      end
    end
    raise 'Qwirk not configured' unless @@config && @@config[adapter_key]
    @@hash[adapter_key] ||= begin
      Qwirk.logger.debug {"Creating Qwirk::AdapterFactory key=#{adapter_key} config=#{@@config[adapter_key].inspect}"}
      config = @@config[adapter_key]
      raise "No config for key #{adapter_key}, keys=#{config.keys.inspect}" unless config
      # Create the adapter, turning all the keys into symbols
      Qwirk::AdapterFactory.new(adapter_key, Hash[config.map{|(k,v)| [k.to_sym,v]}])
    end
  end

  def self.register_adapter(key, publisher_class, worker_config_class, &block)
    AdapterFactory.register(key, publisher_class, worker_config_class, &block)
  end

  def self.fail_queue_name(queue_name)
    return "#{queue_name.to_s}Fail"
  end

  ## From here on down are proxies to the default adapter to keep the API simpler for setups with a single adapter
  # TODO: Allow the setting of the default adapter

  def self.create_publisher(options={})
    self['default'].create_publisher(options)
  end

  def self.create_manager(options={})
    self['default'].create_manager(options)
  end

  def self.create_publisher_impl(queue_name, topic_name, options, response_options)
    self['default'].create_publisher_impl(queue_name, topic_name, options, response_options)
  end

  def self.in_process?
    self['default'].in_process?
  end
end

# We have to define the above before we define the adapters so the Qwirk#register_adapter call will work
# AdapterFactory is also required before adapter for this reason.
require 'qwirk/adapter_factory'
require 'qwirk/adapter'
require 'qwirk/base_worker'
#require 'qwirk/batch'
require 'qwirk/manager'
require 'qwirk/marshal_strategy'
require 'qwirk/publish_handle'
require 'qwirk/publisher'
require 'qwirk/remote_exception'
require 'qwirk/task'
require 'qwirk/worker'
require 'qwirk/reply_worker'

require 'qwirk/engine' if defined?(Rails)
