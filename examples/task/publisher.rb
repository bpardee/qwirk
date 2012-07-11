require 'rumx'
require 'qwirk'

class Publisher
  include Rumx::Bean

  bean_attr_reader   :tasks, :list,    'Tasks', :list_type => :bean

  bean_operation :perform_task, :void, 'Perform task which will send <count> messages to the worker and write the output to <output_file>', [
      [ :task_id,     :string,  'Id for this task ',                         'task1'        ],
      [ :count,       :integer, 'Count of messages',                         1000           ],
      [ :message,     :string,  'String portion of the message to send',     'M'            ],
      [ :sleep_time,  :float,   'Time to sleep between messages',            0.0            ],
      [ :output_file, :string,  'Output file to write returned messages to', 'messages.out' ]
  ]

  def initialize(adapter_factory_key)
    @adapter_factory_key = adapter_factory_key
    @tasks       = []
  end

  def perform_task(task_id, count, message, sleep_time, output_file)
    @tasks << Task.new(@adapter_factory_key, task_id, count, message, sleep_time, output_file)
  end
end
