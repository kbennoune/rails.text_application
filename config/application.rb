require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TextApplication
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.time_zone = 'Eastern Time (US & Canada)'
    config.active_record.default_timezone = :local

    config.eager_load_paths.concat( Dir[Rails.root.join('app', 'support', '*')] )
    config.eager_load_paths.concat( Dir[Rails.root.join('app', 'forms', '*')] )
    config.autoload_paths.concat( Dir[Rails.root.join('app', 'wrappers', '*')] )

    config.i18n.load_path += Dir[ Rails.root.join('config', 'locales','*', '*.{rb,yml}').to_s]
    config.i18n.load_path += Dir[ Rails.root.join('config', 'locales','*', '*.texts').to_s]

    I18n.available_locales = [:en, :es]
    I18n.default_locale = :en
    config.x.allowed_text_application_host = /.*/
  end
end
