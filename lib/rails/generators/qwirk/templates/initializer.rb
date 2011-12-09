module Cheese
  class Engine < Rails::Engine
    config.mount_at = '/qwirk'
    config.widget_factory_name = 'Qwirk'
  end
end
