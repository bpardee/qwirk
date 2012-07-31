require 'rubygems'
require 'rumx'
require 'qwirk/loggable'

module Qwirk
  extend Qwirk::Loggable

  DEFAULT_NAME = 'Qwirk'

  @@config = nil
  @@hash   = {}

  class MyBean
    include Rumx::Bean

    # These are actually AdapterFactory's but presenting as adapters to the user.
    bean_attr_reader :adapters,  :hash, 'Adapters', :hash_type => :bean

    def initialize(hash)
      @adapters = hash
    end
  end

  def self.config=(config)
    @@config = config
    Rumx::Bean.root.bean_add_child(DEFAULT_NAME, MyBean.new(@@hash))
  end

  def self.[](adapter_key)
    if @@config.nil?
      if defined?(Rails)
        # Allow user to use JMS w/o modifying qwirk.yml which could be checked in and hose other users
        env = ENV['QWIRK_ENV'] || Rails.env
        self.config = YAML.load(ERB.new(File.read(Rails.root.join("config", "qwirk.yml")), nil, '-').result(binding))[env]
        Manager.default_options = {
            :persist_file    => Rails.root.join('log', 'qwirk_persist.yml'),
            :worker_file     => Rails.root.join('config', 'qwirk_workers.yml'),
            :stop_on_signal  => true,
            :env             => env,
        }
      end
    end
    raise 'Qwirk not configured' unless @@config && @@config[adapter_key]
    Qwirk.logger.debug {"Creating Qwirk::AdapterFactory key=#{adapter_key} config=#{@@config[adapter_key].inspect}"}
    @@hash[adapter_key] ||= Qwirk::AdapterFactory.new(adapter_key, @@config[adapter_key])
  end

  def self.register_adapter(key, publisher_class, worker_config_class, &block)
    AdapterFactory.register(key, publisher_class, worker_config_class, &block)
  end

  def self.fail_queue_name(queue_name)
    return "#{queue_name.to_s}Fail"
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
