require 'rumx'
require 'qwirk'

class Task
  include Qwirk::Task

  def initialize(adapter_key, task_id, total_count, message, sleep_time, output_file)
    publisher = Qwirk[adapter_key].create_publisher(:queue_name => 'Foo', :marshal => :bson, :persistent => false, :response => {:time_to_live => 10000, :marshal => :string})
    super(publisher, task_id, total_count)
    @out = File.open(output_file, 'w')
    (1..total_count).each do |i|
      obj = {'count' => i, 'message' => message}
      #puts "Publishing object: #{obj.inspect}"
      publish(obj)
      sleep sleep_time
    end
    finish
  end

  def on_response(request, response)
    #puts "For request #{request}, got response #{response}"
    @out.puts response
  end

  def on_exception(request, exception)
    puts "For request #{request} got exception #{exception.message}"
  end

  def on_update()
  end

  def on_done
    @out.close
    puts "We're done"
  end
end
