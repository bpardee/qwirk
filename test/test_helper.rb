ENV["RAILS_ENV"] = "test"
ENV['BUNDLE_GEMFILE'] ||= File.expand_path("../../Gemfile", __FILE__)

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('..', __FILE__)

require 'rubygems'
require 'bundler/setup'
require 'qwirk'
require 'minitest/autorun'
