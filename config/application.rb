require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Lurepedia
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # `analyzers` is required explicitly at boot (see
    # config/initializers/active_storage_analyzers.rb), not autoloaded.
    config.autoload_lib(ignore: %w[assets tasks analyzers])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Use ImageMagick (mini_magick) for Active Storage variants. ImageMagick is
    # installed in the production image (see Dockerfile) and on dev machines.
    config.active_storage.variant_processor = :mini_magick

    # Internationalization
    config.i18n.available_locales = %i[en de bg ja fr es el zh ru nl it pt ko sv no]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [ :en ]
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]
  end
end
