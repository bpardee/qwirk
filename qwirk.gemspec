Gem::Specification.new do |s|
  s.name        = 'qwirk'
  s.version     = '0.2.1'
  s.summary     = 'Background task and Asynchronous RPC library'
  s.description = 'Library for performing background tasks as well as asynchronous and parallel RPC calls'
  s.authors     = ['Brad Pardee']
  s.email       = ['bradpardee@gmail.com']
  s.homepage    = 'http://github.com/ClarityServices/qwirk'
  s.files       = Dir["{lib}/**/*"] + %w(LICENSE.txt Rakefile History.md README.md)
  s.test_files  = Dir["test/**/*"]

  s.add_dependency 'rumx', ['>= 0.2.3']
  s.add_dependency 'rack'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'bson'
  s.add_development_dependency 'bson_ext' unless s.platform.to_s == 'java'
  s.add_development_dependency 'json'
  s.add_development_dependency 'minitest'
  #s.add_development_dependency 'minitest-rails-capybara'
  #s.add_development_dependency 'mocha'
  #s.add_development_dependency 'factory_girl_rails'
  s.add_development_dependency 'turn'
end
