module Qwirk
  class RemoteException < Exception
    attr_accessor :originating_exception_name
    attr_accessor :originating_exception_message

    def initialize(originating_exception=nil, message=nil)
      super(message)
      if originating_exception
        @originating_exception_name = originating_exception.class.name
        @originating_exception_message = originating_exception.message
        set_backtrace(originating_exception.backtrace)
      end
      @message = message
    end

    def message
      @message || @originating_exception_message
    end

    def message=(msg)
      @message = msg
    end

    def to_hash
      {
          'message'                       => @message,
          'originating_exception_name'    => @originating_exception_name,
          'originating_exception_message' => @originating_exception_message,
          'backtrace'                     => backtrace
      }
    end

    def marshal
      to_hash.to_yaml
    end

    def self.from_hash(hash)
      exc = new
      exc.message                       = hash['message']
      exc.originating_exception_name    = hash['originating_exception_name']
      exc.originating_exception_message = hash['originating_exception_message']
      exc.set_backtrace(hash['backtrace'])
      return exc
    end

    def self.unmarshal(yaml_str)
      from_hash(YAML.load(yaml_str))
    end
  end
end
