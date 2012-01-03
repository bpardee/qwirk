Gem::Specification.new do |s|
  s.name        = "qwirk"
  s.summary     = 'Asynchronous task library'
  s.description = 'Generic asynchronous task library'
  s.platform    = 'java'
  s.authors     = ['Brad Pardee']
  s.email       = ['bradpardee@gmail.com']
  s.homepage    = 'http://github.com/ClarityServices/qwirk'
  s.files       = Dir["{app,examples,lib,config}/**/*"] + %w(LICENSE.txt Rakefile Gemfile History.md README.md)
  s.version     = '0.0.1.alpha1'

  # Rakefile needs to create spec for both platforms (ruby and java), using the
  # $platform global variable. In all other cases, we figure it out from RUBY_PLATFORM.
  s.platform = $platform || RUBY_PLATFORM[/java/] || 'ruby'

  s.add_dependency 'jruby-jms', ['>= 0.11.2'] if spec.platform.to_s == 'java'
  s.add_dependency 'gene_pool', ['>= 1.2.0']
  s.add_dependency 'rumx'
  s.add_dependency 'rack'
end
