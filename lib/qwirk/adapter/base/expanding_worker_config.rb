module Qwirk
  module Adapter
    module Base
      class ExpandingWorkerConfig < WorkerConfig

        bean_reader        :count,               :integer, 'Current number of workers'
        bean_attr_accessor :min_count,           :integer, 'Min number of workers allowed', :config_item => true
        bean_attr_accessor :max_count,           :integer, 'Max number of workers allowed', :config_item => true
        bean_attr_accessor :idle_worker_timeout, :integer, 'Timeout where an idle worker will be removed from the worker pool and it\'s resources closed (0 for no removal)', :config_item => true
        bean_attr_accessor :max_read_threshold,  :float,   'Threshold where a new worker will be added if none of the workers have had to wait this amount of time on a read', :config_item => true

        # Define the default config values for the attributes all workers will share.  These will be sent as options to the constructor
        def self.initial_default_config
          super.merge(:min_count => 0, :max_count => 0, :idle_worker_timeout => 60, :max_read_threshold => 1.0)
        end

        def init
          super
          @workers          = []
          @min_count        = 0
          @max_count        = 0
          @index_count      = 0
          @index_mutex      = Mutex.new
          @worker_mutex     = Mutex.new
          @worker_condition = ConditionVariable.new
        end

        def count
          @worker_mutex.synchronize { return @workers.size }
        end

        def min_count=(new_min_count)
          return if @min_count == new_min_count
          raise "#{self.worker_class.name}-#{self.name}: Can't change count since we've been stopped" if self.stopped
          Qwirk.logger.info "#{self.worker_class.name}: Changing min number of workers from #{@min_count} to #{new_min_count}"
          self.max_count = new_min_count if @max_count < new_min_count
          @worker_mutex.synchronize do
            add_worker while @workers.size < new_min_count
            @min_count = new_min_count
          end
        end

        def max_count=(new_max_count)
          return if @max_count == new_max_count
          raise "#{self.worker_class.name}-#{self.name}: Can't change count since we've been stopped" if self.stopped
          Qwirk.logger.info "#{self.worker_class.name}: Changing max number of workers from #{@max_count} to #{new_max_count}"
          self.min_count = new_max_count if @min_count > new_max_count
          @min_count = 1 if @min_count == 0 && new_max_count > 0
          @worker_mutex.synchronize do
            @timer ||= Rumx::Beans::TimerAndError.new
            if @workers.size > new_max_count
              @workers[new_max_count..-1].each { |worker| worker.stop }
              while @workers.size > new_max_count
                @workers.last.stop
                @worker_condition.wait(@worker_mutex)
              end
            end
            @max_count = new_max_count
          end
        end

        def stop
          Qwirk.logger.debug { "In expanding_worker_config stop" }
          # First stop the impl.  For InMem, this will not return until all the messages in the queue have
          # been processed since these messages are not persistent.
          @impl.stop
          @worker_mutex.synchronize do
            @workers.each { |worker| worker.stop }
            while @workers.size > 0
              @worker_condition.wait(@worker_mutex)
            end
            super
          end
        end

        def worker_stopped(worker)
          remove_worker(worker)
        end

        def periodic_call(poll_time)
          now = Time.now
          add_new_worker = true
          worker_stopped = false
          @worker_mutex.synchronize do
            # reverse_each to remove later workers first
            @workers.reverse_each do |worker|
              start_worker_time = worker.start_worker_time
              start_read_time = worker.start_read_time
              if !start_read_time || (now - start_worker_time) < (poll_time + @max_read_threshold)
                #Qwirk.logger.debug { "#{self}: Skipping newly created worker" }
                add_new_worker = false
                next
              end
              end_read_time = worker.start_processing_time
              # If the processing time is actually from the previous processing, then we're probably still waiting for the read to complete.
              if !end_read_time || end_read_time < start_read_time
                if !worker_stopped && @workers.size > @min_count && (now - start_read_time) > @idle_worker_timeout
                  worker.stop
                  worker_stopped = true
                end
                end_read_time = now
              end
              #Qwirk.logger.debug { "#{self}: start=#{start_read_time} end=#{end_read_time} thres=#{@max_read_threshold} add_new_worker=#{add_new_worker}" }
              add_new_worker = false if (end_read_time - start_read_time) > @max_read_threshold
            end
            add_worker if add_new_worker && @workers.size < @max_count
          end
        end

        private

        def add_worker
          worker = self.worker_class.new
          worker.init(@index_count, self)
          worker.start
          Qwirk.logger.debug {"#{self}: Adding worker #{worker}"}
          @index_mutex.synchronize { @index_count += 1 }
          @workers << worker
        rescue Exception => e
          Qwirk.logger.error("Unable to add #{self.worker_class} worker: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
        end

        def remove_worker(worker)
          Qwirk.logger.debug {"#{self}: Deleting worker #{worker}"}
          @worker_mutex.synchronize do
            @workers.delete(worker)
            @worker_condition.broadcast
          end
        end
      end
    end
  end
end
