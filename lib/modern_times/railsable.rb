require 'yaml'
require 'erb'

module ModernTimes
  module Railsable
    def init_rails
      # Allow user to use JMS w/o modifying jms.yml which could be checked in and hose other users
      @env = ENV['MODERN_TIMES_ENV'] || Rails.env
      if @config = YAML.load(ERB.new(File.read(File.join(Rails.root, "config", "jms.yml"))).result(binding))[@env]
        ModernTimes.logger.info "Messaging Enabled"
        ModernTimes::JMS::Connection.init(@config)
        @is_jms_enabled = true

        # Need to start the JMS Server in this VM
        # TODO: Still want to support this?
        if false
        #if ModernTimes::JMS::Connection.invm?
          @server = ::JMS::Server.create_server('vm://127.0.0.1')
          @server.start

          # Handle messages within this process
          @manager = ModernTimes::Manager.new
          # TODO: Formatting of configured workers in invm state with name and options
          if worker_cfg = @config[:workers]
            worker_cfg.each do |klass, count|
              @manager.add(klass, count, {})
            end
          else
            rails_workers.each do |klass|
              @manager.add(klass, 1, {})
            end
          end

          at_exit do
            @manager.stop if @manager
            @server.stop
          end
        end

      else
        Rails.logger.info "Messaging disabled"
        @is_jms_enabled = false
        ModernTimes::JMS::Publisher.setup_dummy_publishing(rails_workers.map {|klass| klass.new({})})
      end
    end

    def create_rails_manager(manager_config={})
      # Take advantage of nil and false values for boolean
      raise 'init_rails has not been called, modify your config/environment.rb to include this call' if @is_jms_enabled.nil?
      raise 'Messaging is not enabled, modify your config/jms.yml file' unless @is_jms_enabled
      default_config = {
          :persist_file    => File.join(Rails.root, "log", "modern_times.yml"),
          :worker_file     => File.join(Rails.root, "config", "workers.yml"),
          :jmx             => @env != 'test',
          :stop_on_signal  => true,
          :dummy_host      => @env,
          :allowed_workers => rails_workers,
      }

      return ModernTimes::Manager.new(default_config.merge(manager_config))
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
      #file = "#{Rails.root}/config/workers.yml"
      #raise "No worker config file #{file}" unless File.exist?(file)
    end

    def config
      @config
    end
    
    def jms_enabled?
      @is_jms_enabled
    end
  end
end
