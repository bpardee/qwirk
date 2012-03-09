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
    include Rumx::Bean

    bean_attr_accessor :max_pending_records, :integer, 'The max number of records published that have not been responded to yet.'
    bean_attr_reader   :task_id,             :string,  'The ID for this task'
    bean_attr_reader   :success_count,       :integer, 'The number of successful responses'
    bean_attr_reader   :exception_count,     :integer, 'The number of exception responses'
    bean_attr_reader   :total_count,         :integer, 'The total expected records to be published (optional)'

    module ClassMethods
    end

    def self.included(base)
      #Qwirk::BaseWorker.included(base)
      Rumx::Bean.included(base)
      base.extend(ClassMethods)
    end

    def initialize(publisher, task_id, total_count, opts={})
      @publisher              = publisher
      @pending_hash           = Hash.new
      @pending_hash_mutex     = Mutex.new
      @pending_hash_condition = ConditionVariable.new
      @task_id                = task_id
      @stopped                = false
      @finished_publishing    = false
      @max_pending_records    = opts[:max_pending_records] || 100
      @success_count          = 0
      @exception_count        = 0
      @total_count            = total_count

      @producer, @consumer   = publisher.create_producer_consumer_pair(@task_id)
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

    def publish(object)
      @pending_hash_mutex.synchronize do
        while @pending_hash.size >= @max_pending_records
          @pending_hash_condition.wait(@pending_hash_mutex)
        end
      end
      raise "#{self}: Invalid publish, we've been stopped" if @stopped
      marshaled_object = @publisher.marshaler.marshal(object)
      message_id = @producer.send(marshaled_object)
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
      @consumer.stop if @consumer
      @stopped = true
    end

    def reply_event_loop
      while !@stopped && pair = @consumer.receive
        message_id, response = pair
        @pending_hash_mutex.synchronize do
          unless @stopped
            request = @pending_hash.delete(message_id)
            if request
              if response.kind_of?(RemoteException)
                on_exception(request, response)
                @exception_count += 1
              else
                on_response(request, response)
                @success_count += 1
              end
              do_stop if @finished_publishing && @pending_hash.empty?
              @pending_hash_condition.signal
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
