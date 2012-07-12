class SharedWorker
  include Qwirk::Worker

  config_accessor :sleep_time, :float, 'Number of seconds to sleep between messages', 5
  config_reader   :message, :string, 'Message'

  def perform(obj)
    puts "#{self}: Received #{obj.inspect} at #{Time.now}"
    sleep config.sleep_time
  end
end
