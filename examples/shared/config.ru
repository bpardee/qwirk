require '../setup'
require './shared_worker'
require './publisher'

# If we're not starting up a standalone publisher, then start up a manager
if ENV['RACK_ENV'] != 'publisher'
  manager = Qwirk::Manager.new(:name => 'Worker', :persist_file => 'qwirk_persist.yml')
  at_exit { manager.stop }
end
if ENV['RACK_ENV'] != 'worker'
  Rumx::Bean.root.bean_add_child(:Publisher, Publisher.new)
end
run Rumx::Server
