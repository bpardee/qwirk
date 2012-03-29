module Qwirk

  # Base Worker Class for any class that will be processing requests from queues and replying
  module RequestWorker
    include Worker

    module ClassMethods
      # Define the marshaling and time_to_live that will occur on the response
      def response(options)
        queue_options[:response] = options
      end

      # By default, exceptions don't get forwarded to a fail queue (they get returned to the caller)
      def default_fail_queue_target
        false
      end
    end

    def self.included(base)
      Worker.included(base)
      base.extend(ClassMethods)
    end

    def perform(object)
      begin
        response = request(object)
      rescue Exception => e
        on_exception(e)
      else
        adapter.send_response(message, config.marshaler.marshal(response))
      end
      post_request(object)
    rescue Exception => e
      Qwirk.logger.error("Exception in send_response or post_request: #{e.message}")
      log_backtrace(e)
    end

    def request(object)
      raise "#{self}: Need to override request method in #{self.class.name} in order to act on #{object}"
    end

    # Handle any processing that you want to perform after the reply
    def post_request(object)
    end

    #########
    protected
    #########

    def on_exception(e)
      begin
        adapter.send_exception(message, e)
      rescue Exception => e
        Qwirk.logger.error("Exception in exception reply: #{e.message}")
        log_backtrace(e)
      end

      # Send it on to the fail queue if it was explicitly set (See default_fail_queue_target above)
      super
    end
  end
end
