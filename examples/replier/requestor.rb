require 'rumx'
require 'qwirk'

class MessageInfo
  include Rumx::Bean

  bean_attr_reader :request,  :string, 'The message that was sent'
  bean_attr_reader :response, :string, 'The response that was received'

  def initialize(request, response)
    @request, @response = request, response
  end
end

class Requestor
  include Rumx::Bean

  bean_reader :messages,  :list,   'Messages', :list_type => :bean

  bean_operation :publish, :void, 'Publish and receive messages', [
      [ :message,      :string,  'Message to get sent',                                                       'Hello' ],
      [ :timeout,      :float,   'Timeout on receiving response',                                             4.0     ],
      [ :sleep_time,   :float,   "Time between publishing and receiving where we're supposedly working",      2.0     ],
      [ :thread_count, :integer, 'Number of different threads that are publishing and receiving the message', 10      ]
  ]


  def initialize(adapter_key)
    @outstanding_hash_mutex = Mutex.new
    @messages = []
    @publisher = Qwirk[adapter_key].create_publisher(:queue_name => 'ReverseEcho', :response => {:time_to_live => 10000}, :marshal => :string)
  end

  def publish(message, timeout, sleep_time, thread_count)
    @outstanding_hash_mutex.synchronize do
      @messages = []
    end
    threads   = []
    (0...thread_count).each do |i|
      threads << Thread.new(i) do |i|
        puts "#{i}: Publishing at #{Time.now.to_f}"
        request = "##{i}: #{message}"
        response = nil
        begin
          handle = @publisher.publish(request)
          # Here's where we'd go off and do other work
          sleep sleep_time
          puts "#{i}: Finished sleeping at #{Time.now.to_f}"
          response = handle.read_response(timeout)
          if handle.timeout?
            puts "#{i}: Timeout at #{Time.now.to_f}"
          else
            puts "#{i}: Received at #{Time.now.to_f}: #{response}"
          end
        rescue Exception => e
          puts "#{i}: Exception: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
          response = e.message
        end
        @outstanding_hash_mutex.synchronize do
          @messages << MessageInfo.new(request, response)
        end
      end
    end
    threads.each {|t| t.join}
  end

  def messages
    @outstanding_hash_mutex.synchronize do
      return @messages.dup
    end
  end
end
