Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Sitemap (locale-independent)
  get "sitemap.xml" => "sitemaps#index", defaults: { format: "xml" }, as: :sitemap

  # Bare root → default locale (must precede the optional-locale scope)
  root to: redirect("/#{I18n.default_locale}")

  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
    # Auth
    resource :session, only: %i[new create destroy]
    resource :registration, only: %i[new create]

    # Account
    resource :settings, only: %i[edit update]
    namespace :my do
      resources :catches, only: :index
    end

    # Catalog
    resources :lures, only: %i[index new create edit]
    get   "lures/:id(/:tab)", to: "lures#show", as: :lure, constraints: { tab: /buy|history/ }
    patch "lures/:id", to: "lures#update"
    resources :species, only: %i[index new create edit]
    get   "species/:id(/:tab)", to: "species#show", as: :species, constraints: { tab: /catches|leaderboard|history/ }
    patch "species/:id", to: "species#update"
    resources :brands, only: %i[index new create edit]
    get   "brands/:id(/:tab)", to: "brands#show", as: :brand, constraints: { tab: /history/ }
    patch "brands/:id", to: "brands#update"
    resources :shops, only: %i[index new create]
    resources :catches, only: %i[index show new create] do
      resources :comments, only: :create
      resource :upvote, only: %i[create destroy]
    end

    # Discovery
    get "search", to: "search#index"
    get "leaderboard", to: "leaderboard#index"

    # Public profiles
    get "u/:handle", to: "profiles#show", as: :profile

    # Edit history detail (git-style diff of a single revision)
    resources :revisions, only: :show

    # Paginated, searchable options for the large filter dropdowns
    get "options/species", to: "filter_options#species", as: :species_options
    get "options/brands", to: "filter_options#brands", as: :brand_options

    # Living styleguide
    get "design-system", to: "design_system#index", as: :design_system

    # Contribution / community
    resources :claims, only: %i[new create] do
      member { post :verify }
    end
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
