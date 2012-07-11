class CharCountWorker
  include Qwirk::ReplyWorker

  topic 'test_string', :response => {:marshal => :bson, :time_to_live => 5000}
  config_accessor :sleep_time, :float, 'Number of seconds to sleep between messages', 0

  def request(obj)
    if config.sleep_time > 0.0
      puts "#{self}: Sleeping for #{config.sleep_time} at #{Time.now}"
      sleep config.sleep_time
    end
    hash = Hash.new(0)
    obj.each_char {|c| hash[c] += 1}
    hash
  end
end
