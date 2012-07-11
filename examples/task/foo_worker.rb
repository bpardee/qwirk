class FooWorker
  include Qwirk::ReplyWorker

  config_accessor :sleep_time, :float, 'Number of seconds to sleep between messages', 5

  def request(hash)
    sleep config.sleep_time
    '%s%04d' % [hash['message'], hash['count']]
  end
end
