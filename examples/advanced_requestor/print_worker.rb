class PrintWorker
  include Qwirk::Worker

  topic 'test_string'
  config_accessor :sleep_time, :float, 'Number of seconds to sleep between messages', 0

  def perform(obj)
    if config.sleep_time > 0.0
      puts "#{self}: Sleeping for #{config.sleep_time} at #{Time.now}"
      sleep config.sleep_time
    end
    puts "#{self}: Received #{obj} at #{Time.now}"
  end
end
