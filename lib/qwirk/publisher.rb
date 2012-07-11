# Protocol independent class to handle Publishing
module Qwirk
  class Publisher
    include Rumx::Bean

    #attr_reader :producer_options, :persistent, :reply_queue
    attr_reader :response_options, :impl, :marshaler

    bean_attr_reader :tasks, :hash, 'Hash of the latest tasks', :hash_type => :bean

    # Parameters:
    #   One of the following must be specified
    #     :queue_name            => String: Name of the Queue to publish to
    #     :topic_name            => String: Name of the Topic to publish to
    #   Optional:
    #     :time_to_live          => expiration time in ms for the message (JMS)
    #     :persistent            => true or false (defaults to false) (JMS)
    #     :marshal               => Symbol: One of :ruby, :string, :json, :bson, :yaml or any registered types (See Qwirk::MarshalStrategy), defaults to :ruby
    #     :response              => if true or a hash of response options, a temporary reply queue will be setup for handling responses
    #       :time_to_live        => expiration time in ms for the response message(s) (JMS))
    #       :persistent          => true or false for the response message(s), set to false if you don't want timed out messages ending up in the DLQ (defaults to true unless time_to_live is set)
    def initialize(adapter_factory, options)
      options = options.dup
      @queue_name = options.delete(:queue_name)
      @topic_name = options.delete(:topic_name)
      raise "One of :queue_name or :topic_name must be given in #{self.class.name}" if !@queue_name && !@topic_name

      @response_options = options.delete(:response)
      # response_options should only be a hash or the values true or false
      @response_options = {} if @response_options && !@response_options.kind_of?(Hash)

      @tasks      = {}
      @impl       = adapter_factory.create_publisher_impl(@queue_name, @topic_name, options, @response_options)
      marshal_sym = options[:marshal] || :ruby
      @marshaler  = Qwirk::MarshalStrategy.find(marshal_sym)
    end

    # Publish the given object to the address.
    def publish(object, props={})
      start = Time.now
      marshaled_object = @marshaler.marshal(object)
      adapter_info = @impl.publish(marshaled_object, @marshaler, nil, props)
      return PublishHandle.new(self, adapter_info, start)
    end

    # Creates a producer/consumer pair for writing and reading responses for a given task.  It will return a pair of
    # [producer, consumer].  The producer will publish objects specifically for the task.  The consumer is an object that responds_to
    # receive which will return a [message_id, response object] and acknowledge_message which will acknowledge the
    # last message read.  It should also respond to stop which will interrupt any receive calls causing it to return nil.
    def create_producer_consumer_pair(task)
      @tasks[task.task_id] = task
      @impl.create_producer_consumer_pair(task.task_id, @marshaler)
    end

    def to_s
      "#{self.class.name}:#{@queue_name || @topic_name}"
    end

    def default_fail_queue_name
      Qwirk.fail_queue_name(@queue_name || @topic_name)
    end

    def create_fail_queue_consumer(fail_queue_name=nil)
      fail_queue_name || default_fail_queue_name
    end
  end
end
