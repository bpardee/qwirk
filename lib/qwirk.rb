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
    raise 'Qwirk not configured' unless @@config && @@config[key]
    @@hash[key] ||= Qwirk::Adapter.new(@@config[key])
  end
end

require 'qwirk/engine' if defined?(Rails)
