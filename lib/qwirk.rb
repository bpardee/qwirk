require 'rubygems'
require 'qwirk/remote_exception'
require 'qwirk/marshal_strategy'
require 'qwirk/base_worker'
require 'qwirk/worker_config'
require 'qwirk/worker'
require 'qwirk/publisher'
require 'qwirk/publish_handle'
require 'qwirk/queue_adapter'
#require 'qwirk/batch'
require 'qwirk/manager'
require 'qwirk/loggable'
require 'qwirk/railsable'

module Qwirk
  extend Qwirk::Loggable
  extend Qwirk::Railsable

  DEFAULT_NAME = 'Qwirk'
end
