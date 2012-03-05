source "http://rubygems.org"

gem 'rumx', '>= 0.2.0'
gem 'rack'

platforms :jruby do
  gem 'jruby-jms', '>= 0.11.2'
  gem 'jruby-activemq'
  # jms doensn't include this dependency yet
  gem 'gene_pool'
end

group :development do
  gem 'rake'
  gem 'rdoc'
  gem 'bson'
  gem 'json'
end

group :test do
  #gem 'jdbc-sqlite3'
  gem 'activerecord-jdbcmysql-adapter'
  gem 'jdbc-mysql'
  gem 'shoulda'
end
