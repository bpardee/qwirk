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
  manager = Qwirk[$adapter_key].create_manager(
      :name         => 'Worker',
      :env          => 'demo',
      :worker_file  => 'qwirk_workers.yml',
      :persist_file => 'qwirk_persist.yml'
  )
  at_exit { manager.stop }
end
if ENV['RACK_ENV'] != 'worker'
  Rumx::Bean.root.bean_add_child(:Publisher, Publisher.new($adapter_key))
end
run Rumx::Server
