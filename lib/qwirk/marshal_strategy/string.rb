module Qwirk
  module MarshalStrategy
    module String
      extend self

      def marshal_type
        :text
      end

      def to_sym
        :string
      end

      def marshal(object)
        object.to_s
      end

      def unmarshal(msg)
        msg
      end

      MarshalStrategy.register(self)
    end
  end
end
