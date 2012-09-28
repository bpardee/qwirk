module Qwirk
  module Remote
    class Client
      include ::Rumx::Bean

      bean_attr_reader   :servers, :hash,  'Remote servers', :hash_type => :bean
      bean_attr_accessor :timeout, :float, 'Timeout for individual calls to remote servers'

      bean_operation   :refresh, :string, 'Query all the remote servers for their current state', [
          [ :timeout,   :float,  'How long to wait for all the servers to respond', 10.0]
      ]

      def initialize(adapter_factory, options={})
        @adapter_factory = adapter_factory
        @options         = options
        @servers = {}
        @timeout = 10.0
      end

      def refresh(timeout)
        new_servers = {}
        success_servers = []
        failure_servers = []
        publisher = Qwirk::Publisher.new(@adapter_factory, :topic_name => Qwirk::Remote.topic_name, :marshal => :bson, :ttl => timeout, :response => true)
        publisher.publish(:command => 'serialize').read_response(timeout) do |response|
          response.on_message do |hash|
            remote_name = Remote.remote_name(response.name)
            new_servers[remote_name] = ::Rumx::RemoteBean.new(hash, self, remote_name)
            success_servers << remote_name
          end
          response.on_remote_exception do |e|
            remote_name = Remote.remote_name(response.name)
            new_servers[remote_name] = ::Rumx::Beans::Message.new(e.message)
            failure_servers << remote_name
          end
        end
        @servers = new_servers
        answer = ''
        answer = "Success for #{success_servers.inspect}" unless success_servers.empty?
        unless failure_servers.empty?
          answer += ', ' unless answer.empty?
          answer += 'Failure for #{failure_servers.inspect}'
        end
        return answer
      end

      def run_operation(ancestry, operation, argument_hash, remote_name)
        puts "In run_operation"
        value = remote_call(remote_name, :command => 'operation', :operation_name => operation.name, :ancestry => ancestry, :argument_hash => argument_hash)
        return operation.type.string_to_value(value['value'])
      end

      def set_attributes(ancestry, params, remote_name)
        puts "In set_attributes"
        remote_call(remote_name, :command => 'attributes', :ancestry => ancestry, :params => params)
      end

      #######
      private
      #######

      def remote_call(remote_name, request)
        publisher = Qwirk::Publisher.new(@adapter_factory, :queue_name => Remote.queue_name(remote_name), :marshal => :bson, :ttl => @timeout, :response => true)
        handle = publisher.publish(request)
        response = handle.read_response(timeout)
        raise Timeout::Error if handle.timeout?
        return response
      end
    end
  end
end
