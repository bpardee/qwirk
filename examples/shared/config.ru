require '../setup'
require './shared_worker'
require './publisher'

# If we're not starting up a standalone publisher, then start up a manager
if ENV['RACK_ENV'] != 'publisher'
  SharedWorker.define_configs(
      'S1' => {:message => "I'm S1", :sleep_time => 10},
      'S2' => {:message => "I'm S2"}
  )
  manager = Qwirk[$adapter_key].create_manager(:name => 'Worker', :persist_file => 'qwirk_persist.yml')
  at_exit { manager.stop }
end
if ENV['RACK_ENV'] != 'worker'
  Rumx::Bean.root.bean_add_child(:Publisher, Publisher.new($adapter_key))
end
run Rumx::Server
