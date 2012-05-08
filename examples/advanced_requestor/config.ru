require '../setup'
require './publisher'
require './char_count_worker'
require './exception_raiser_worker'
require './length_worker'
require './print_worker'
require './reverse_worker'
require './triple_worker'

# If we're not starting up a standalone publisher, then start up a manager
if ENV['RACK_ENV'] != 'publisher'
  manager = Qwirk[$adapter_key].create_manager(:name => 'Worker', :persist_file => 'qwirk_persist.yml')
  manager['CharCount'].max_count       = 1
  manager['ExceptionRaiser'].max_count = 1
  manager['Length'].max_count          = 1
  manager['Print'].max_count           = 1
  manager['Reverse'].max_count         = 1
  manager['Triple'].max_count          = 1
  at_exit { manager.stop }
end
if ENV['RACK_ENV'] != 'worker'
  Rumx::Bean.root.bean_add_child(:Publisher, Publisher.new($adapter_key))
end
run Rumx::Server
