module Qwirk

  # Base Worker Class for any class that will be processing messages from topics or queues
  # By default, it will consume messages from a queue with the class name minus the Worker postfix.
  # For example, the queue call is unnecessary as it will default to a value of 'Foo' anyways:
  #  class FooWorker
  #    include Qwirk::QueueAdapter::JMS::Worker
  #    queue 'Foo'
  #    def perform(obj)
  #      # Perform work on obj
  #    end
  #  end
  #
  # A topic can also be specified.  Note that for JMS, this is only supported under ActiveMQ.  On others,
  # each thread for a given worker will act as a separate subscriber.
  # (For ActiveMQ - see http://activemq.apache.org/virtual-destinations.html):
  #  class FooWorker
  #    include Qwirk::QueueAdapter::JMS::Worker
  #    topic 'Zulu'
  #    def perform(obj)
  #      # Perform work on obj
  #    end
  #  end
  #
  # TODO (maybe):
  # Filters can also be specified within the class:
  #  class FooWorker
  #    include Qwirk::QueueAdapter::JMS::Worker
  #    filter 'age > 30'
  #    def perform(obj)
  #      # Perform work on obj
  #    end
  #  end
  #
  #
  module Worker
    include Qwirk::BaseWorker

    attr_accessor :message
    attr_reader   :status, :adapter, :start_worker_time, :start_read_time, :start_processing_time

    module ClassMethods
      def queue(name, opts={})
        # If we're using the default name but we still want to set queue options, then a name won't be given.
        if name.kind_of?(Hash)
          @queue_options = name
        else
          @queue_name = name.to_s
          @queue_options = opts
        end
      end

      def topic(name, options={})
        @topic_name = name.to_s
        @queue_options = options
      end

      # Set the fail_queue
      # target =>
      #   boolean
      #     true - exceptions in the worker will cause the message to be forwarded to the queue of <default-name>Fail
      #       For instance, an Exception in FooWorker#perform will forward the message to the queue FooFail
      #     false - exceptions will not result in the message being forwarded to a fail queue
      #   string - equivalent to true but the string defines the name of the fail queue
      def fail_queue(target, opts={})
        @fail_queue_target = target
      end

      def fail_queue_target
        @fail_queue_target
      end

      # Defines the default value of the fail_queue_target.  For extenders of this class, the default will be true
      # but extenders can change this (RequestWorker returns exceptions to the caller so it defaults to false).
      def default_fail_queue_target
        true
      end

      def queue_name(default_name)
        puts "getting queue_name queue=#{@queue_name} topic=#{@topic_name} default=#{default_name}"
        return @queue_name if @queue_name
        return nil if @topic_name
        return default_name
      end

      def topic_name
        @topic_name
      end

      def queue_options
        @queue_options ||= {}
      end

      def fail_queue_name(worker_config)
        # TBD - Set up fail_queue as a config
        target = self.class.fail_queue_target
        # Don't overwrite if the user set to false, only if it was never set
        target = self.class.default_fail_queue_target if target.nil?
        if target == true
          return "#{config.name}Fail"
        elsif target == false
          return nil
        elsif target.kind_of?(String)
          return target
        else
          raise "Invalid fail queue: #{target}"
        end
      end
    end

    def self.included(base)
      Qwirk::BaseWorker.included(base)
      base.extend(ClassMethods)
    end

    def start(index, worker_config)
      @status               = 'Started'
      @stopped              = false
      @processing_mutex     = Mutex.new
      self.index  = index
      self.config = worker_config
      @adapter = worker_config.adapter.create_worker
      self.thread = Thread.new do
        java.lang.Thread.current_thread.name = "Qwirk worker: #{self}" if RUBY_PLATFORM == 'jruby'
        #Qwirk.logger.debug "#{worker}: Started thread with priority #{Thread.current.priority}"
        event_loop
      end
    end

    # Workers will be starting and stopping on an as needed basis.  Thus, when they get a stop command they should
    # clean up any resources.  We don't want to clobber resources while a message is being processed so processing_mutex will surround
    # message processessing and worker closing.
    # From a JMS perspective, stop all workers (close consumer and session), stop the config.
    # From an InMem perspective, we don't want the workers stopping until all messages in the queue have been processed.
    # Therefore we want to stop the
    def stop
      puts "#{self}: In base worker stop"
      @status  = 'Stopping'
      @stopped = true
      @processing_mutex.synchronize do
        # This should interrupt @adapter.receive_message above and cause it to return nil
        @adapter.stop
      end
      puts "#{self}: base worker stop complete"
    end

    def perform(object)
      raise "#{self}: Need to override perform method in #{self.class.name} in order to act on #{object}"
    end

    def to_s
      "#{config.name}:#{index}"
    end

    # Allow override of backtrace logging in case the client doesn't want to get spammed with it (maybe just config instead?)
    def log_backtrace(e)
      Qwirk.logger.error "\t#{e.backtrace.join("\n\t")}"
    end

    #########
    protected
    #########

    # Start the event loop for handling messages off the queue
    def event_loop
      Qwirk.logger.debug "#{self}: Starting receive loop"
      @start_worker_time = Time.now
      while !@stopped && !config.adapter.stopped
        puts "#{self}: Waiting for read"
        @start_read_time = Time.now
        msg = @adapter.receive_message
        if msg
          @start_processing_time = Time.now
          Qwirk.logger.debug {"#{self}: Done waiting for read in #{@start_processing_time - @start_read_time} seconds"}
          delta = config.timer.measure do
            @processing_mutex.synchronize do
              on_message(msg)
              @adapter.acknowledge_message(msg)
            end
          end
          Qwirk.logger.info {"#{self}::on_message (#{'%.1f' % delta}ms)"} if self.config.log_times
          Qwirk.logger.flush if Qwirk.logger.respond_to?(:flush)
        end
      end
      Qwirk.logger.info "#{self}: Exiting"
    rescue Exception => e
      @status = "Terminated: #{e.message}"
      Qwirk.logger.error "#{self}: Exception, thread terminating: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    ensure
      @status = 'Stopped'
      # TODO: necessary?
      @adapter.stop
      Qwirk.logger.flush if Qwirk.logger.respond_to?(:flush)
      config.worker_stopped(self)
    end

    def on_message(message)
      # TBD - Is it necessary to provide underlying message to worker?  Should we generically provide access to message attributes?  Do filters somehow fit in here?
      @message = message
      object = @adapter.message_to_object(message)
      Qwirk.logger.debug {"#{self}: Received Object: #{object}"}
      perform(object)
    rescue Exception => e
      on_exception(e)
    ensure
      Qwirk.logger.debug {"#{self}: Finished processing message"}
    end

    def on_exception(e)
      Qwirk.logger.error "#{self}: Messaging Exception: #{e.message}"
      log_backtrace(e)
      @adapter.handle_failure(message, @fail_queue_name) if @fail_queue_name
    rescue Exception => e
      Qwirk.logger.error "#{self}: Exception in exception reply: #{e.message}"
      log_backtrace(e)
    end

    def fail_queue_name
      @fail_queue_name
    end
  end
end
