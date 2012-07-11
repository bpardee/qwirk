require 'erb'
require 'yaml'
require 'socket'
require 'rumx'

module Qwirk
  class Manager
    include Rumx::Bean
    attr_reader   :env, :worker_configs, :name

    bean_attr_accessor :poll_time, :float, 'How often the manager should poll the workers for their status for use by :idle_worker_timeout and :max_read_threshold'

    @@default_options = {}

    def self.default_options=(options)
      @@default_options = options
    end

    # Constructs a manager.  Accepts a hash of config options
    #   name         - name which this bean will be added
    #   env          - environment being executed under.  For a rails project, this will be the value of Rails.env
    #   worker_file  - the worker file is a hash with the environment or hostname as the primary key and a subhash with the worker names
    #     as the keys and the config options for the value.  In this file, the env will be searched first and if that doesn't exist,
    #     the hostname will then be searched.  Workers can be defined for development without having to specify the hostname.  For
    #     production, a set of workers could be defined under production or specific workers for each host name.
    #   persist_file - WorkerConfig attributes that are modified externally (via Rumx interface) will be stored in this file.  Without this
    #     option, external config changes that are made will be lost when the Manager is restarted.
    def initialize(adapter_factory, options={})
      @adapter_factory    = adapter_factory
      options           = @@default_options.merge(options)
      @stopped          = false
      @name             = options[:name] || Qwirk::DEFAULT_NAME
      @poll_time        = 3.0
      @worker_configs   = []
      @env              = options[:env]
      @worker_options   = parse_worker_file(options[:worker_file])
      @persist_file     = options[:persist_file]
      @persist_options  = (@persist_file && File.exist?(@persist_file)) ? YAML.load_file(@persist_file) : {}

      BaseWorker.worker_classes.each do |worker_class|
        worker_class.each_config(adapter_factory.worker_config_class) do |config_name, extended_worker_config_class, default_options|
          # Least priority is config default_options defined in the Worker class, then the workers.yml file,
          # highest priority is persist_file (ad-hoc changes made manually)
          options = {}
          options = options.merge(@worker_options[config_name]) if @worker_options[config_name]
          options = options.merge(@persist_options[config_name]) if @persist_options[config_name]
          worker_config = extended_worker_config_class.new(adapter_factory, config_name, self, worker_class, default_options, options)
          bean_add_child(config_name, worker_config)
          @worker_configs << worker_config
        end
      end

      start_timer_thread
      stop_on_signal if options[:stop_on_signal]
    end

    # Create a timer_thread to make periodic calls to the worker_configs in order to do such things as expand/contract
    # workers, etc.
    def start_timer_thread
      # TODO: Optionize hard-coded values
      @timer_thread = Thread.new do
        begin
          while !@stopped
            @worker_configs.each do |worker_config|
              worker_config.periodic_call(@poll_time)
            end
            sleep @poll_time
          end
        rescue Exception => e
          Qwirk.logger.error "Timer thread failed with exception: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
        end
      end
    end

    def stop
      return if @stopped
      @stopped = true
      @timer_thread.wakeup
      @worker_configs.each { |worker_config| worker_config.stop }
    end

    def stop_on_signal
      ['HUP', 'INT', 'TERM'].each do |signal_name|
        Signal.trap(signal_name) do
          Qwirk.logger.info "Caught #{signal_name}"
          stop
        end
      end
    end

    # Store off any options that are no longer set to default
    def save_persist_state
      return unless @persist_file
      new_persist_options = {}
      BaseWorker.worker_classes.each do |worker_class|
        worker_class.each_config(@adapter_factory.worker_config_class) do |config_name, ignored_extended_worker_config_class, default_options|
          static_options = default_options.merge(@worker_options[config_name] || {})
          worker_config = self[config_name]
          hash = {}
          # Only store off the config values that are specifically different from default values or values set in the workers.yml file
          # Then updates to these values will be allowed w/o being hardcoded to an old default value.
          worker_config.bean_get_attributes do |attribute_info|
            if attribute_info.attribute[:config_item] && attribute_info.ancestry.size == 1
              param_name = attribute_info.ancestry[0].to_sym
              value = attribute_info.value
              hash[param_name] = value if static_options[param_name] != value
            end
          end
          new_persist_options[config_name] = hash unless hash.empty?
        end
      end
      if new_persist_options != @persist_options
        @persist_options = new_persist_options
        File.open(@persist_file, 'w') do |out|
          YAML.dump(@persist_options, out )
        end
      end
    end

    def [](name)
      @worker_configs.each do |worker_config|
        return worker_config if worker_config.name == name
      end
      return nil
    end

    #######
    private
    #######

    def parse_worker_file(file)
      if file && File.exist?(file)
        hash = YAML.load(ERB.new(File.read(file), nil, '-').result(binding))
        options = @env && hash[@env]
        unless options
          host = Socket.gethostname.sub(/\..*/, '')
          options = hash[host]
        end
      end
      return options || {}
    end
  end
end
