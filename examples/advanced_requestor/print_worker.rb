class PrintWorker
  include Qwirk::JMS::Worker

  topic 'test_string'

  def perform(obj)
    puts "#{self}: Received #{obj} at #{Time.now}"
  end
end
