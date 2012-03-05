require '../setup'
require './reverse_echo_worker'
require './requestor'

# If we're not starting up a standalone requestor, then start up a manager
if ENV['RACK_ENV'] != 'requestor'
  manager = Qwirk::Manager.new(:name => 'Worker', :persist_file => 'qwirk_persist.yml')
  manager['ReverseEcho'].max_count = 1
  at_exit { manager.stop }
end
if ENV['RACK_ENV'] != 'worker'
  Rumx::Bean.root.bean_add_child(:Requestor, Requestor.new)
end
run Rumx::Server
