source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.1.4'
# Use mysql as the database for Active Record
gem 'mysql2'
# Use Puma as the app server
gem 'puma', '~> 3.7'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use CoffeeScript for .coffee assets and views
# gem 'coffee-rails', '~> 4.2'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 3.0'
gem 'sidekiq'

# Use ActiveModel has_secure_password
gem 'omniauth'
gem 'omniauth-facebook', '~>4.0.0'
gem 'omniauth-google-oauth2', '~>0.5.3'
# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

gem 'c_geohash', require: 'geohash'
gem 'simhilarity'
gem 'fuzzy_match'

gem 'tzinfo'
gem 'tzinfo-data'

# Fixes bug where eagerload blanks out eager_loaded
# attributes defined in select.
gem 'rails_select_on_includes'

gem 'browser'

gem 'sidekiq'
gem "sidekiq-cron", "~> 0.6.3"

gem 'proxy_fetcher', '~> 0.6'

gem 'ruby-bandwidth'

gem 'rollbar'
gem 'rails_admin'

# gem 'ruby-vobject', git: 'git@github.com:riboseinc/ruby-vobject.git', tag: '0.2.0', require: ['vcard']
gem 'vcardigan'

gem 'fuzzily'

gem 'bullet', group: 'development'

group :development, :test do
  gem 'rb-readline'
  gem 'webmock'
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  # Adds support for Capybara system testing and selenium driver
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

group :test do
  gem 'minitest', '5.10.3'
  gem 'minitest-rails-capybara'
  gem 'capybara', '~> 2.13'
  gem 'selenium-webdriver'
  gem 'minitest-reporters'
  gem 'minitest-around'
  gem 'ffaker'
  gem 'faker'

end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem "jwt", "~> 1.5"
