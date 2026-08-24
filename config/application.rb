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

    # Serve images through the app instead of redirecting to storage. The
    # default redirect mode costs a full extra round-trip before the browser
    # can even start the real download — measured as most of a 6s LCP on lure
    # pages. Proxy responses carry a 1-year immutable Cache-Control (Rails'
    # ActiveStorage::Representations::ProxyController), so repeat views by the
    # same visitor cost nothing further.
    config.active_storage.resolve_model_to_route = :rails_storage_proxy

    # Internationalization
    config.i18n.available_locales = %i[en de bg ja fr es el zh ru nl it pt ko sv no pl cs fi da]

    # Which of those locales we ask search engines to index (see Locales).
    # Every locale ships translated UI chrome, but catalog copy — lure and
    # species descriptions — is English-only outside :en, so the other 18 are
    # near-duplicates of the English set. Publishing all of them made a ~41k-URL
    # crawl surface that buried the English pages under ~20k "crawled/discovered,
    # currently not indexed" URLs. Add a locale back once its catalog copy is
    # genuinely translated; it stays fully browsable either way.
    config.x.indexable_locales = %i[en]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [ :en ]
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]
  end
end
