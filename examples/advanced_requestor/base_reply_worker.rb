module BaseReplyWorker
  include Qwirk::ReplyWorker

  config_accessor :sleep_time, :float, 'Number of seconds to sleep between messages', 0

  def self.included(base)
    Qwirk::Worker.included(base)
  end

  def perform(obj)
    puts "#{self}: Received #{obj} at #{Time.now}"
    if config.sleep_time > 0.0
      puts "#{self}: Sleeping for #{config.sleep_time} at #{Time.now}"
      sleep config.sleep_time
    end
    super
  end
end
