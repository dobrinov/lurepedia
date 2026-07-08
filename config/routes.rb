Rails.application.routes.draw do
  # Fly also answers on www and the *.fly.dev hostname, each a full duplicate
  # copy whose canonical tags point at themselves — 301 them to the apex so
  # crawlers see a single site. /up stays reachable on any host for Fly's
  # health checks (mirrors production.rb's ssl_options exclusion).
  match "(*path)", via: :all, to: redirect(host: "lurepedia.com", status: 301),
    constraints: ->(req) { %w[www.lurepedia.com lurepedia.fly.dev].include?(req.host) && req.path != "/up" }

  get "up" => "rails/health#show", as: :rails_health_check

  # OmniAuth callbacks are locale-independent: the provider's redirect URI is a
  # fixed, registered path, so these live outside the optional (:locale) scope.
  get  "/auth/:provider/callback", to: "sessions/omniauth#create", as: :omniauth_callback
  get  "/auth/failure",            to: "sessions/omniauth#failure", as: :omniauth_failure

  # Sitemap (locale-independent). /sitemap.xml is a sitemap index that points
  # at one per-locale sitemap; each /sitemaps/<locale>.xml lists that language's
  # URLs (with the full hreflang alternate set).
  get "sitemap.xml" => "sitemaps#index", defaults: { format: "xml" }, as: :sitemap
  get "sitemaps/:locale.xml" => "sitemaps#show", constraints: { locale: /#{I18n.available_locales.join("|")}/ },
    defaults: { format: "xml" }, as: :locale_sitemap

  # Bare root: served here for everyone, but anonymous visitors are redirected
  # to a canonical locale-prefixed home by Application#canonicalize_root_locale.
  # Signed-in visitors stay on "/" and get locale-free URLs.
  # (Must precede the optional-locale scope.)
  root to: "lures#index"

  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
    # Auth
    resource :session, only: %i[new create destroy]
    resource :registration, only: %i[new create]

    # Account
    resource :settings, only: %i[edit update] do
      patch :password
    end
    namespace :my do
      resources :catches, only: :index
    end

    # Catalog
    resources :lures, only: %i[index new create edit]
    get   "lures/:id/variation-options", to: "lures#variations", as: :lure_variation_options, defaults: { format: :json }
    scope "lures/:lure_id" do
      resources :variants, only: %i[new create edit update destroy]
      resources :builds, only: %i[new create edit update destroy]
      resources :buy_links, only: :create
      resources :lure_links, only: %i[create destroy]
      post "similar-preview", to: "lure_links#preview", as: :lure_similar_preview
    end
    get   "lures/:id(/:tab)(/:color)", to: "lures#show", as: :lure, constraints: { tab: /caught|buy|history|variations/ }
    # A bare trailing segment that is not a tab is a color on the default tab:
    # /lures/<slug>/<color>. Tab+color is /lures/<slug>/<tab>/<color> above.
    get   "lures/:id/:color", to: "lures#show", as: :lure_color
    patch "lures/:id", to: "lures#update"
    resources :species, only: %i[index new create edit]
    get   "species/:id(/:tab)", to: "species#show", as: :species, constraints: { tab: /catches|leaderboard|history/ }
    patch "species/:id", to: "species#update"
    resources :brands, only: %i[index new create edit]
    get   "brands/:id(/:tab)", to: "brands#show", as: :brand, constraints: { tab: /history/ }
    patch "brands/:id", to: "brands#update"
    resources :shops, only: %i[index show new create edit update]
    resources :catches, only: %i[index show new create destroy] do
      resources :comments, only: :create
      resource :upvote, only: %i[create destroy]
    end

    # Discovery
    get "leaderboard", to: "leaderboard#index"

    # Public profiles
    get "u/:handle(/:tab)", to: "profiles#show", as: :profile, constraints: { tab: /catches|favorites|contributions|settings/ }

    # Edit history detail (git-style diff of a single revision)
    resources :revisions, only: :show

    # Paginated, searchable options for the large filter dropdowns
    get "options/species", to: "filter_options#species", as: :species_options
    get "options/brands", to: "filter_options#brands", as: :brand_options
    get "options/lures", to: "filter_options#lures", as: :lure_options
    get "options/shops", to: "filter_options#shops", as: :shop_options

    # Living styleguide
    get "design-system", to: "design_system#index", as: :design_system

    # Contribution / community
    resources :claims, only: %i[new create]
    resources :reports, only: :create
    resources :favorites, only: :create do
      delete :destroy, on: :collection
    end

    # Staff
    resources :moderation, only: %i[index update]
    namespace :admin do
      root to: "dashboard#overview"
      get "people", to: "dashboard#people"
      get "activity", to: "dashboard#activity"
      resources :users, only: :update do
        resources :bans, only: %i[index create] do
          member { patch :revoke }
        end
      end
    end

    root to: "lures#index", as: :localized_root
  end
end
