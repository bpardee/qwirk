module Qwirk
  module Adapter
    module JMS
      class Util
        class << self
          def create_message(session, marshaled_object, marshal_type)
            case marshal_type
              when :text
                session.create_text_message(marshaled_object)
              when :bytes
                msg = session.create_bytes_message()
                msg.data = marshaled_object
                msg
              else raise "Invalid marshal type: #{marshal_type}"
            end
          end

          def parse_response(message)
            if error_yaml = message['qwirk:exception']
              return Qwirk::RemoteException.from_hash(YAML.load(error_yaml))
            end
            marshaler = Qwirk::MarshalStrategy.find(message['qwirk:marshal'] || WorkerConfig.default_marshal_sym)
            return marshaler.unmarshal(message.data)
          end
        end
      end
    end
  end
end

