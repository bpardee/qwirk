require 'yaml'
require 'erb'

module Qwirk
  module Railsable
    def init_rails
      # Allow user to use JMS w/o modifying jms.yml which could be checked in and hose other users
      @env = ENV['MODERN_TIMES_ENV'] || Rails.env
      if @config = YAML.load(ERB.new(File.read(File.join(Rails.root, "config", "jms.yml"))).result(binding))[@env]
        Qwirk.logger.info "Messaging Enabled"
        Qwirk::QueueAdapter::JMS::Connection.init(@config)
        @is_jms_enabled = true

        # Need to start the JMS Server in this VM
        # TODO: Still want to support this?
        if false
        #if Qwirk::QueueAdapter::JMS::Connection.invm?
          @server = ::JMS::Server.create_server('vm://127.0.0.1')
          @server.start
          # Handle messages within this process
          @manager = Qwirk::Manager.new

          at_exit do
            @manager.stop if @manager
            @server.stop
          end
        end

      end
    end

    def create_rails_manager(manager_config={})
      # Take advantage of nil and false values for boolean
      raise 'init_rails has not been called, modify your config/environment.rb to include this call' if @is_jms_enabled.nil?
      raise 'Messaging is not enabled, modify your config/jms.yml file' unless @is_jms_enabled
      default_config = {
          :persist_file    => File.join(Rails.root, "log", "qwirk_persist.yml"),
          :worker_file     => File.join(Rails.root, "config", "qwirk_workers.yml"),
          :stop_on_signal  => true,
          :env             => @env,
      }

      return Qwirk::Manager.new(default_config.merge(manager_config))
    end

    def rails_workers
      @rails_workers ||= begin
        workers = []
        Dir["#{Rails.root}/app/workers/*_worker.rb"].each do |file|
          require file
          workers << File.basename(file).sub(/\.rb$/, '').classify.constantize
        end
        workers
      end
    end

    def config
      @config
    end
  end
end
