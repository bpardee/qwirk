# Handle Messaging and Queuing using JMS
module Qwirk
  module Adapter
    module JMS
      class Worker
        def initialize(worker_config)
          @worker_config = worker_config
          @name          = worker_config.name
          @marshaler     = worker_config.marshaler
          @session       = worker_config.connection.create_session
          @consumer      = @session.consumer(worker_config.destination)
          @session.start
        end

        def receive_message
          @consumer.receive
        end

        def acknowledge_message(msg)
          msg.acknowledge
        end

        def send_response(original_message, marshaled_object)
          do_send_response(@marshaler, original_message, marshaled_object)
        end

        def send_exception(original_message, e)
          @string_marshaler ||= MarshalStrategy.find(:string)
          do_send_response(@string_marshaler, original_message, "Exception: #{e.message}") do |reply_message|
            reply_message['qwirk:exception'] = Qwirk::RemoteException.new(e).to_hash.to_yaml
          end
        end

        def message_to_object(msg)
          marshaler = Qwirk::MarshalStrategy.find(msg['qwirk:marshal'] || :ruby)
          return marshaler.unmarshal(msg.data)
        end

        def handle_failure(message, exception, fail_queue_name)
          @session.producer(:queue_name => fail_queue_name) do |producer|
            # TODO: Can't add attribute to read-only message?
            #message['qwirk:exception'] = Qwirk::RemoteException.new(e).to_hash.to_yaml
            producer.send(message)
          end
        end

        def stop
          return if @stopped
          Qwirk.logger.info "Stopping JMS worker #{@name}"
          # Don't clobber the session before a reply
          @consumer.close if @consumer
          @session.close if @session
          @stopped = true
        end

        private

        def do_send_response(marshaler, original_message, marshaled_object)
          return false unless original_message.reply_to
          begin
            @session.producer(:destination => original_message.reply_to) do |producer|
              # For time_to_live and jms_deliver_mode, first use the local response_options if they're' set, otherwise
              # use the value from the original_message attributes if they're' set
              time_to_live = @time_to_live || original_message['qwirk:response:time_to_live']
              persistent   = @persistent
              persistent = (original_message['qwirk:response:persistent'] == 'true') if persistent.nil? && original_message['qwirk:response:persistent']
              # If persistent isn't set anywhere, then default to true unless time_to_live has been set
              persistent = !time_to_live if persistent.nil?
              # The reply is persistent if we explicitly set it or if we don't expire
              producer.delivery_mode_sym = persistent ? :persistent : :non_persistent
              producer.time_to_live = time_to_live.to_i if time_to_live
              reply_message = Util.create_message(@session, marshaled_object, marshaler.marshal_type)
              reply_message.jms_correlation_id = original_message.jms_message_id
              reply_message['qwirk:marshal'] = marshaler.to_sym.to_s
              reply_message['qwirk:worker']  = @name
              reply_message['QwirkTaskID']   = original_message['QwirkTaskID'] if original_message['QwirkTaskID']
              yield reply_message if block_given?
              producer.send(reply_message)
            end
          rescue Exception => e
            Qwirk.logger.error {"Error attempting to send response: #{e.message}\n\t#{e.backtrace.join("\n\t")}"}
          end
          return true
        end
      end
    end
  end
end
