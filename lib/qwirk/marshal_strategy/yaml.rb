module Qwirk
  module MarshalStrategy
    module YAML
      extend self

      def marshal_type
        :text
      end

      def to_sym
        :yaml
      end

      def marshal(object)
        object.to_yaml
      end

      def unmarshal(msg)
        ::YAML.load(msg)
      end

      MarshalStrategy.register(self)
    end
  end
end
