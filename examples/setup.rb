# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require 'rubygems'
require 'qwirk'
require 'rumx'
require 'erb'
require 'yaml'
require 'logger'

#Qwirk.logger = Logger.new($stdout)

jms_file = File.expand_path('../jms.yml', __FILE__)
if File.exist?(jms_file)
  config = YAML.load(ERB.new(File.read(jms_file)).result(binding))
  Qwirk::JMS::Connection.init(config)
  Qwirk::QueueAdapter.set(:jms)
else
  Qwirk::QueueAdapter.set(:in_mem)
end
