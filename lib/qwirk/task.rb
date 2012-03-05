module Qwirk

  # Batch worker which reads records from files and queues them up for a separate worker (Qwirk::QueueAdapter::JMS::RequestWorker) to process.
  # For instance, a worker of this type might look as follows:
  #   class MyBatchWorker
  #     include Qwirk::Batch::FileWorker
  #
  #     file :glob => '/home/batch_files/input/**', :age => 1.minute, :max_pending_records => 100, :fail_threshold => 0.8, :save_period => 30.seconds
  #     marshal :string
  #   end
  #
  # The following options can be used for configuring the class
  #   file:
  #     :glob => <glob_path>
  #       The path where files will be processed from.  Files will be renamed with a .processing extension while they are being processed
  #       and to a .completed extension when processing is completed.
  #     :age => <duration>
  #       How old a file must be before it will be processed.  This is to prevent files that are in the middle of being uploaded from begin acquired.
  #     :poll_time => <duration>
  #       How often the glob is queried for new files.
  #     :max_pending_records => <integer>
  #       This is how many records can be queued at a time.
  #     :
  module Task
    #include Qwirk::BaseWorker

    module ClassMethods
    end

    def self.included(base)
      #Qwirk::BaseWorker.included(base)
      base.extend(ClassMethods)
    end

    def initialize(publisher, task_id, opts={})
      @pending_hash           = Hash.new
      @pending_hash_mutex     = Mutex.new
      @pending_hash_condition = ConditionVariable.new
      @publisher              = publisher
      @task_id                = task_id
      @stopped                = false
      @finished_publishing    = false
      @max_pending_records    = opts[:max_pending_records] || 100

      @reply_thread = Thread.new do
        java.lang.Thread.current_thread.name = "Qwirk task: #{task_id}"
        reply_event_loop
        on_done
      end
    end

    # Stuff to override
    def on_response(request, response)
    end

    def on_exception(request, exception)
    end

    def on_update()
    end

    def on_done()
    end

    def publish(object, props={})
      @pending_hash_mutex.synchronize do
        while @pending_hash.size >= @max_pending_records
          @worker_condition.wait(@worker_mutex)
        end
      end
      raise "#{self}: Invalid publish, we've been stopped" if @stopped
      message_id = @publisher.publish(object, props)
      @pending_hash_mutex.synchronize do
        @pending_hash[message_id] = object
      end
    end

    # TODO: Needed?
    def start
    end

    def stop
      do_stop
      @reply_thread.join
    end

    def finish
      @finished_publishing = true
      @pending_hash_mutex.synchronize do
        do_stop if @pending_hash.empty?
      end
      @reply_thread.join
    end

    #######
    private
    #######

    def do_stop
      return if @stopped
      @consumer.close if @consumer
      @stopped = true
    end

    def reply_event_loop
      @consumer = @publisher.create_task_consumer(@task_id)

      while !@stopped && pair = @consumer.read_response
        message_id, response = pair
        @pending_hash_mutex.synchronize do
          unless @stopped
            request = @pending_hash.delete(message_id)
            if request
              if response.kind_of(RemoteException)
                on_exception(request, response)
              else
                on_response(request, response)
              end
              do_stop if @finished_publishing && @pending_hash.empty?
              @worker_condition.signal
            else
              Qwirk.logger.warn("#{self}: Read unexpected response with message_id=#{message_id}")
            end
            @consumer.acknowledge_message
          end
        end
      end
      do_stop
      Qwirk.logger.info "#{self}: Exiting"
    rescue Exception => e
      do_stop
      Qwirk.logger.error "#{self}: Exception, thread terminating: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    end
  end
end
