module Qwirk
  module Remote

    # Setup the remote worker with a unique name with which to identify this particular process.
    # This defaults to the simple hostname (minus the domain name) which can be used if their is only
    # one qwirk_manager running on this host, otherwise it should be some combination of the hostname
    # and process name or anything that would uniquely identify the process/host combination.
    # Options:
    #   name - overrides the default name for this process/host combination.
    #   topic_name - name of the topic.  This should be the same for all process/host combinations and
    #                defaults to 'remote'
    def self.setup(adapter_factory, options={})
      require 'qwirk/remote/client'
      require 'qwirk/remote/worker'

      options = options.dup
      @@adapter_factory = adapter_factory
      @@name            = options.delete(:name) || default_name
      @@topic_name      = options.delete(:topic_name) || 'remote'
      @@queue_name      = self.queue_name(@@name)
      @@root_bean_name  = options.delete(:root_bean_name) || @@topic_name
      default_options   = {:min_count => 1, :max_count => 1}
      Worker.define_configs(
          "TRemote_#{@@name}" => default_options.merge(:topic_name => @@topic_name).merge(options),
          "QRemote_#{@@name}" => default_options.merge(:queue_name => @@queue_name).merge(options)
      )
      client = Client.new(adapter_factory, options)
      @@root_bean = Rumx::Bean.add_root(@@root_bean_name, ::Rumx::Beans::Folder.new)
      @@root_bean.bean_add_child(:client, client)
    end

    def self.adapter_factory
      @@adapter_factory
    end

    def self.name
      @@name
    end

    def self.topic_name
      @@topic_name
    end

    def self.queue_name(name)
      "Remote_#{name}"
    end

    def self.root_bean
      @@root_bean
    end

    def self.default_name
      require 'socket'
      name = Socket.gethostname
      name.sub(/\..*/, '')
    end

    def self.remote_name(worker_name)
      worker_name.sub(/^[QT]Remote_/, '')
    end
  end
end
