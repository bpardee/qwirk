module Qwirk

  # The following options can be used for configuring the class
  #     :
  module Task
    #include Qwirk::BaseWorker
    include Rumx::Bean

    bean_attr_reader   :task_id,             :string,  'The ID for this task'
    bean_attr_reader   :publish_count,       :integer, 'The number of requests that have been published'
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
      @publisher           = publisher
      @mutex               = Mutex.new
      @condition           = ConditionVariable.new
      @task_id             = task_id
      @stopped             = false
      @finished_publishing = false
      @retry               = opts[:retry]
      @auto_retry          = opts[:auto_retry]
      @publish_count       = 0
      @success_count       = 0
      @exception_count     = 0
      @total_count         = total_count
      @exceptions_per_run  = []

      @producer, @consumer = publisher.create_producer_consumer_pair(self)
      @reply_thread = Thread.new do
        java.lang.Thread.current_thread.name = "Qwirk task: #{task_id}"
        reply_event_loop
        on_done
      end
    end

    # Stuff to override
    def on_response(response)
    end

    def on_exception(exception)
    end

    def on_update()
    end

    def on_done()
    end

    def retry=(val)
      @retry = val
      if val
        @mutex.synchronize { check_retry }
      end
    end

    def auto_retry=(val)
      @auto_retry = val
      if val
        @mutex.synchronize { check_retry }
      end
    end

    def publish(object)
      marshaled_object = @publisher.marshaler.marshal(object)
      @mutex.synchronize do
        unless @stopped
          @producer.send(marshaled_object)
          @publish_count += 1
        end
      end
    end

    # TODO: Needed?
    def start
    end

    def stop
      @mutex.synchronize { do_stop }
      @reply_thread.join
    end

    def finished_publishing
      @total_count = @publish_count
      @finished_publishing = true
      @mutex.synchronize { check_finish }
      @reply_thread.join
    end

    #######
    private
    #######

    # Must be called within a mutex synchronize
    def do_stop
      return if @stopped
      @consumer.stop if @consumer
      @fail_consumer.stop if @fail_consumer
      @stopped = true
    end

    def reply_event_loop
      while !@stopped && response = @consumer.receive
        @mutex.synchronize do
          unless @stopped
            if response.kind_of?(RemoteException)
              @exception_count += 1
              on_exception(response)
            else
              @success_count += 1
              on_response(response)
            end
            @consumer.acknowledge_message
            check_finish
            @condition.signal
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
      if @finished_publishing
        if @success_count >= @total_count
          do_stop
        else
          check_retry
        end
      end
    end

    # Must be called within a mutex synchronize
    def check_retry
      if @finished_publishing && @exception_count > 0 && (@exception_count+@success_count) == @total_count && (@retry || @auto_retry)
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
            @mutex.synchronize { check_finish }
          rescue Exception => e
            do_stop
            Qwirk.logger.error "#{self}: Exception, thread terminating: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
          end
        end
      end
    end
  end
end
