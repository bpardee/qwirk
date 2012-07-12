require 'rumx'
require 'qwirk'

class Publisher
  include Rumx::Bean

  bean_attr_accessor :s1_count, :integer, 'Number of S1 messages sent'
  bean_attr_accessor :s2_count, :integer, 'Number of S2 messages sent'

  bean_operation :send_s1, :void, 'Send messages to the S1 worker', [
      [ :count,      :integer, 'Count of messages',                     10               ],
      [ :message,    :string,  'String portion of the message to send', 'Message for S1' ],
      [ :sleep_time, :float,   'Time to sleep between messages',        0.2              ]
  ]

  bean_operation :send_s2, :void, 'Send messages to the S2 worker', [
      [ :count,      :integer, 'Count of messages',                     5                ],
      [ :message,    :string,  'String portion of the message to send', 'Message for S2' ],
      [ :sleep_time, :float,   'Time to sleep between messages',        0.5              ]
  ]


  def initialize(adapter_key)
    @s1_publisher = Qwirk[adapter_key].create_publisher(:queue_name => 'S1', :marshal => :bson)
    @s2_publisher = Qwirk[adapter_key].create_publisher(:queue_name => 'S2', :marshal => :string)
    @s1_count = 0
    @s2_count = 0
  end

  def send_s1(count, message, sleep_time)
    count.times do
      @s1_count += 1
      obj = {'count' => @s1_count, 'message' => message}
      puts "Publishing to S1 object: #{obj.inspect}"
      @s1_publisher.publish(obj)
      sleep sleep_time
    end
  end

  def send_s2(count, message, sleep_time)
    count.times do
      @s2_count += 1
      obj = "#{@s2_count}: #{message}"
      puts "Publishing to S2 object: #{obj}"
      @s2_publisher.publish(obj)
      sleep sleep_time
    end
  end
end
