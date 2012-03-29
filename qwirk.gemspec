$:.push File.expand_path("../lib", __FILE__)

require "qwirk/version"

Gem::Specification.new do |s|
  s.name        = "qwirk"
  s.version     = Qwirk::VERSION
  s.summary     = 'Asynchronous task library'
  s.description = 'Generic asynchronous task library'
  #s.platform    = 'java'
  s.authors     = ['Brad Pardee']
  s.email       = ['bradpardee@gmail.com']
  s.homepage    = 'http://github.com/ClarityServices/qwirk'
  s.files       = Dir["{app,examples,lib,config}/**/*"] + %w(LICENSE.txt Rakefile History.md README.md)
  s.test_files  = Dir["test/**/*"]
  s.version     = '0.0.1.alpha1'

  # Rakefile needs to create spec for both platforms (ruby and java), using the
  # $platform global variable. In all other cases, we figure it out from RUBY_PLATFORM.
  s.platform = (defined?($platform) && $platform) || RUBY_PLATFORM[/java/] || 'ruby'

  if s.platform.to_s == 'java'
    s.add_dependency 'jruby-jms', ['>= 0.11.2']
    s.add_dependency 'jruby-activemq'
    # jms doensn't include this dependency yet
    s.add_dependency 'gene_pool', ['>= 1.2.0']
    s.add_development_dependency 'activerecord-jdbcmysql-adapter'
    s.add_development_dependency 'jdbc-mysql'
  end
  s.add_dependency 'rumx', ['>= 0.2.1']
  s.add_dependency 'rack'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'bson'
  s.add_development_dependency 'json'
  s.add_development_dependency 'shoulda'
end
