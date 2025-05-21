require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Matilda
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Set supported languages.
    config.i18n.available_locales = [ :it, :en ]
    config.i18n.default_locale = :it
    I18n.backend.class.send(:include, I18n::Backend::Cascade)

    # Set default storage vairants manager.
    config.active_storage.variant_processor = :mini_magick
    config.active_storage.track_variants = true

    # Load libs
    config.autoload_paths << Rails.root.join("lib")
  end
end
