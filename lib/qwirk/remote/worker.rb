module Qwirk
  module Remote
    class Worker
      include Qwirk::ReplyWorker

      response :marshal => :bson

      #config_accessor :update_threshold, :integer, 'Threshold age in seconds where a new call will be made'

      # Process incoming inquiries
      def request(hash)
        case command = hash['command']
          when 'serialize'
            ::Rumx::Bean.root.bean_to_remote_hash
          when 'operation'
            bean, operation, value = ::Rumx::Bean.run_operation(hash['ancestry'], hash['operation_name'], hash['argument_hash'])
            puts "operation returned #{value}"
            raise "Invalid operation ancestry = #{hash['ancestry'].inspect} operation=#{hash['operation_name'].inspect}" unless bean
            # Allow bson to handle it
            { :value => value }
          when 'attributes'
            bean = ::Rumx::Bean.find(hash['ancestry'])
            raise "Invalid bean ancestry #{hash['ancestry'].inspect}" unless bean
            attributes = bean.bean_set_and_get_attributes(hash['params'])
            puts "attributes returned #{attributes.inspect}"
            attributes
          else
            raise "Invalid command: #{command.inspect}"
        end
      end
    end
  end
end
