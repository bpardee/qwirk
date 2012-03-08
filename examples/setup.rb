# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require 'rubygems'
require 'qwirk'
require 'rumx'
require 'erb'
require 'yaml'
require 'logger'

#Qwirk.logger = Logger.new($stdout)

qwirk_file = File.expand_path('../qwirk.yml', __FILE__)
config = YAML.load(ERB.new(File.read(qwirk_file)).result(binding))
$adapter = Qwirk::Adapter.new(config[ENV['QWIRK_ADAPTER'] || 'in_mem'])
