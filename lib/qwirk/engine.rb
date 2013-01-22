module Qwirk
  class Engine < ::Rails::Engine
    isolate_namespace(Qwirk) if self.respond_to?(:isolate_namespace)
  end
end
