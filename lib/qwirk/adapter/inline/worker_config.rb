# Handle Messaging and Queuing using JMS
module Qwirk
  module Adapter
    module Inline

      class WorkerConfig < Qwirk::Adapter::Base::WorkerConfig

        bean_attr_accessor :active, :boolean, 'Whether this worker is active or not', :config_item => true

        def self.default_marshal_sym
          :none
        end

        # Define the default config values for the attributes all workers will share.  These will be sent as options to the constructor
        def self.initial_default_config
          super.merge(:active => false)
        end

        # Hack - Steal attribute from expanding_worker_config so test config can share development config
        def min_count=(min_count)
          @active = (min_count > 0)
        end

        def create_worker
          Worker.new(self.name, self.marshaler)
        end
      end
    end
  end
end
