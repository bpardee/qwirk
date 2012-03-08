require '../setup'
require './reverse_echo_worker'
require './requestor'

# If we're not starting up a standalone requestor, then start up a manager
if ENV['RACK_ENV'] != 'requestor'
  manager = Qwirk::Manager.new($adapter, :name => 'Worker', :persist_file => 'qwirk_persist.yml')
  at_exit { manager.stop }
end
if ENV['RACK_ENV'] != 'worker'
  Rumx::Bean.root.bean_add_child(:Requestor, Requestor.new($adapter))
end
run Rumx::Server
