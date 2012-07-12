# Handle Messaging and Queuing using JMS
module Qwirk
  module Adapter
    module InMem

      class WorkerConfig < Qwirk::Adapter::Base::ExpandingWorkerConfig

        bean_reader   :queue_size,     :integer, 'Current count of messages in the queue'
        bean_accessor :queue_max_size, :integer, 'Max messages allowed in the queue', :config_item => true

        def self.default_marshal_sym
          :none
        end

        def self.initial_default_config
          super.merge(:queue_max_size => 100)
        end

        def init
          super
          @queue = Factory.get_worker_queue(self.name, self.queue_name, self.topic_name, @queue_max_size)
        end

        def create_worker
          Worker.new(self.name, self.marshaler, @queue)
        end

        def stop
          Qwirk.logger.debug { "Stopping #{self}" }
          @queue.stop
          super
        end

        def queue_size
          return 0 unless @queue
          @queue.size
        end

        def queue_max_size
          @queue_max_size
        end

        def queue_max_size=(max_size)
          @queue_max_size = max_size
          @queue.max_size = max_size if @queue
        end
      end
    end
  end
end
