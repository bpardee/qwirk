module Qwirk
  module MarshalStrategy
    # Should only be used with InMem strategy
    module None
      extend self

      def marshal_type
        :bytes
      end

      def to_sym
        :none
      end

      def marshal(object)
        object
      end

      def unmarshal(msg)
        msg
      end

      MarshalStrategy.register(self)
    end
  end
end
