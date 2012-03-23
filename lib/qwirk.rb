require 'rubygems'
require 'qwirk/remote_exception'
require 'qwirk/marshal_strategy'
require 'qwirk/base_worker'
require 'qwirk/worker_config'
require 'qwirk/worker'
require 'qwirk/request_worker'
require 'qwirk/task'
require 'qwirk/publisher'
require 'qwirk/publish_handle'
require 'qwirk/adapter'
require 'qwirk/queue_adapter'
#require 'qwirk/batch'
require 'qwirk/manager'
require 'qwirk/loggable'

module Qwirk
  extend Qwirk::Loggable

  DEFAULT_NAME = 'Qwirk'

  @@config = nil
  @@hash   = {}

  def self.config=(config)
    @@config = config
  end

  def self.[](key)
    if @@config.nil?
      if defined?(Rails)
        # Allow user to use JMS w/o modifying qwirk.yml which could be checked in and hose other users
        env = ENV['QWIRK_ENV'] || Rails.env
        @@config = YAML.load(ERB.new(File.read(Rails.root.join("config", "qwirk.yml")), nil, '-').result(binding))[env]
        Manager.default_options = {
            :persist_file    => Rails.root.join('log', 'qwirk_persist.yml'),
            :worker_file     => Rails.root.join('config', 'qwirk_workers.yml'),
            :stop_on_signal  => true,
            :env             => env,
        }
      end
    end
    raise 'Qwirk not configured' unless @@config && @@config[key]
    @@hash[key] ||= Qwirk::Adapter.new(@@config[key])
  end
end

require 'qwirk/engine' if defined?(Rails)
