require 'rumx'
require 'qwirk'

class Publisher
  include Rumx::Bean

  bean_attr_reader :messages, :hash,    'Message', :hash_type => :string, :allow_write => false

  bean_operation :publish, :void, 'Publish and receive messages', [
      [ :message,      :string,  'Message to get sent',                                                  'Hello' ],
      [ :timeout,      :float,   'Timeout on receiving response',                                        4.0     ],
      [ :sleep_time,   :float,   "Time between publishing and receiving where we're supposedly working", 2.0     ]
  ]

  def initialize(adapter_key)
    @publisher = Qwirk[adapter_key].create_publisher(:topic_name => 'test_string', :response => true, :marshal => :string)
  end

  def publish(message, timeout, sleep_time)
    @messages = {}
    puts "Publishing at #{Time.now.to_f}"
    handle = @publisher.publish(message)
    sleep sleep_time

    handle.read_response(timeout) do |response|
      response.on_message 'CharCount' do |hash|
        messages['CharCount'] = "returned #{hash.inspect} in #{response.msec_delta.to_i} ms"
      end
      response.on_message 'Length', 'Reverse', 'Triple' do |val|
        messages[response.name] = "returned #{val} in #{response.msec_delta.to_i} ms"
      end
      response.on_message 'ExceptionRaiser' do |val|
        messages[response.name] = "didn't raise an exception, returned \"#{val}\" in #{response.msec_delta.to_i} ms"
      end
      response.on_timeout 'Reverse' do
        messages[response.name] = "Timed out with it's own timeout handler in #{response.msec_delta.to_i} ms"
      end
      response.on_timeout do
        messages[response.name] = "timed out in #{response.msec_delta.to_i} ms"
      end
      response.on_remote_exception 'ExceptionRaiser' do |e|
        messages[response.name] = "It figures that ExceptionRaiser would raise an exception: #{e.message} in #{response.msec_delta.to_i} ms"
      end
      response.on_remote_exception do |e|
        messages[response.name] = "raised exception: #{e.message} in #{response.msec_delta.to_i} ms"
      end
    end
  end
end
