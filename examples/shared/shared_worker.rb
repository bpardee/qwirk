class SharedWorker
  include Qwirk::Worker

  config_accessor :sleep_time, :float, 'Number of seconds to sleep between messages', 5
  config_reader   :message, :string, 'Message'

  define_configs(
    'S1' => {:message => "I'm S1", :sleep_time => 10},
    'S2' => {:message => "I'm S2"}
  )

  def perform(obj)
    puts "#{self}: Received #{obj.inspect} at #{Time.now}"
    sleep config.sleep_time
  end
end
