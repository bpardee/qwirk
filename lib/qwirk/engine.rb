require 'rails'

module Qwirk
  class Engine < Rails::Engine
    initializer "qwirk initialize" , :after =>"active_record.initialize_database" do
      #config.before_configuration do
    end
  end
end
