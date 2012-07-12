class ExceptionRaiserWorker
  include Qwirk::ReplyWorker

  topic 'test_string', :response => {:marshal => :string, :time_to_live => 5000}

  config_accessor :raise_exception, :boolean, 'Raise an exception instead of handling the request', false
  config_accessor :sleep_time, :float, 'Number of seconds to sleep between messages', 0

  def request(obj)
    if config.sleep_time > 0.0
      puts "#{self}: Sleeping for #{config.sleep_time} at #{Time.now}"
      sleep config.sleep_time
    end
    raise "Raising dummy exception on #{obj}" if config.raise_exception
    "We decided not to raise on #{obj}"
  end
end
