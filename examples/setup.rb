# Allow examples to be run in-place without requiring a gem install
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require 'rubygems'
require 'qwirk'
require 'rumx'
require 'yaml'
require 'logger'

#Qwirk.logger = Logger.new($stdout)

Qwirk.config = YAML.load(File.read(File.expand_path('../qwirk.yml', __FILE__)))
$adapter_key = ENV['QWIRK_ADAPTER'] || 'in_mem'
