module Qwirk

  # The following options can be used for configuring the class
  #     :max_pending_records => <integer>
  #       This is how many records can be queued at a time.
  #     :
  module Task
    #include Qwirk::BaseWorker
    include Rumx::Bean

    bean_attr_accessor :max_pending_records, :integer, 'The max number of records that can be published without having been responded to (publishing blocks at this point).'
    bean_attr_reader   :task_id,             :string,  'The ID for this task'
    bean_attr_reader   :success_count,       :integer, 'The number of successful responses'
    bean_attr_reader   :exception_count,     :integer, 'The number of exception responses'
    bean_attr_reader   :total_count,         :integer, 'The total expected records to be published (optional)'
    bean_attr_accessor :retry,               :boolean, 'Retry all the exception responses'
    bean_attr_accessor :auto_retry,          :boolean, 'Continuously retry all the exception responses while at least 1 or more succeeds'
    bean_attr_reader   :exceptions_per_run,  :list,    'Number of exceptions per run, i.e., index 0 contains the count of exceptions in the first run, index 1 in the first retry, etc.', :list_type => :integer

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
      @retry                  = opts[:retry]
      @auto_retry             = opts[:auto_retry]
      @success_count          = 0
      @exception_count        = 0
      @total_count            = total_count
      @exceptions_per_run     = []

      @producer, @consumer   = publisher.create_producer_consumer_pair(self)
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

    def retry=(val)
      @retry = val
      if val
        @pending_hash_mutex.synchronize { check_retry }
      end
    end

    def publish(object)
      marshaled_object = @publisher.marshaler.marshal(object)
      @pending_hash_mutex.synchronize do
        while !@stopped && @pending_hash.size >= @max_pending_records
          @pending_hash_condition.wait(@pending_hash_mutex)
        end
        unless @stopped
          message_id = @producer.send(marshaled_object)
          @pending_hash[message_id] = object
        end
      end
    end

    # TODO: Needed?
    def start
    end

    def stop
      @pending_hash_mutex.synchronize { do_stop }
      @reply_thread.join
    end

    def finished_publishing
      @finished_publishing = true
      @pending_hash_mutex.synchronize { check_finish }
      @reply_thread.join
    end

    #######
    private
    #######

    def verify_fail_queue_creation
      unless @fail_producer
        @fail_producer, @fail_consumer = publisher.create_producer_fail_consumer_pair(@task_id)
      end
    end

    def publish_fail_request(object)
      verify_fail_queue_creation
      marshaled_object = @publisher.marshaler.marshal(object)
      @fail_producer.send(marshaled_object)
    end

    # Must be called within a mutex synchronize
    def do_stop
      return if @stopped
      @consumer.stop if @consumer
      @fail_consumer.stop if @fail_consumer
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
                publish_fail_request(request)
                on_exception(request, response)
                @exception_count += 1
              else
                on_response(request, response)
                @success_count += 1
              end
            else
              Qwirk.logger.warn("#{self}: Read unexpected response with message_id=#{message_id}")
            end
            @consumer.acknowledge_message
            check_finish
            @pending_hash_condition.signal
          end
        end
      end
      do_stop
      Qwirk.logger.info "#{self}: Exiting"
    rescue Exception => e
      do_stop
      Qwirk.logger.error "#{self}: Exception, thread terminating: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    end

    # Must be called within a mutex synchronize
    def check_finish
      if @finished_publishing && @pending_hash.empty?
        if @exception_count == 0
          do_stop
        else
          check_retry
        end
      end
    end

    # Must be called within a mutex synchronize
    def check_retry
      if @finished_publishing && @pending_hash.empty? && @exception_count > 0 && (@retry || @auto_retry)
        # If we're just doing auto_retry but nothing succeeded last time, then don't run again
        return if !@retry && @auto_retry && @exception_count == @exceptions_per_run.last
        Qwirk.logger.info "#{self}: Retrying exception records, exception count = #{@exception_count}"
        @exceptions_per_run << @exception_count
        @exception_count = 0
        @finished_publishing = false
        @fail_thread = Thread.new(@exceptions_per_run.last) do |count|
          begin
            java.lang.Thread.current_thread.name = "Qwirk fail task: #{task_id}"
            while !@stopped && (count > 0) && (object = @fail_consumer.receive)
              count -= 1
              publish(object)
              @fail_consumer.acknowledge_message
            end
            @finished_publishing = true
            @pending_hash_mutex.synchronize { check_finish }
          rescue Exception => e
            do_stop
            Qwirk.logger.error "#{self}: Exception, thread terminating: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
          end
        end
      end
    end
  end
end
