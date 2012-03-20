require 'rails'

module Qwirk
  class Engine < Rails::Engine
    config.before_configuration do
      # Allow user to use JMS w/o modifying qwirk.yml which could be checked in and hose other users
      env = ENV['QWIRK_ENV'] || Rails.env
      config = YAML.load(ERB.new(File.read(Rails.root.join("config", "qwirk.yml")), nil, '-').result(binding))[env]
      return unless config
      Qwirk.config = config
      Manager.default_options = {
          :persist_file    => Rails.root.join('log', 'qwirk_persist.yml'),
          :worker_file     => Rails.root.join('config', 'qwirk_workers.yml'),
          :stop_on_signal  => true,
          :env             => env,
      }
    end
  end
end
