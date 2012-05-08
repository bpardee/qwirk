require '../setup'
require './reverse_echo_worker'
require './requestor'

# If we're not starting up a standalone publisher, then start up a manager
if ENV['RACK_ENV'] != 'publisher'
  manager = Qwirk[$adapter_key].create_manager(:name => 'Worker', :persist_file => 'qwirk_persist.yml')
  at_exit { manager.stop }
end
if ENV['RACK_ENV'] != 'worker'
  Rumx::Bean.root.bean_add_child(:Requestor, Requestor.new($adapter_key))
end
run Rumx::Server
