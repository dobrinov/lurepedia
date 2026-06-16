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
    resources :lures, only: %i[index show new create edit update]
    resources :species, only: %i[index show new create edit update]
    resources :brands, only: %i[index show new create edit update]
    resources :shops, only: %i[index new create]
    resources :catches, only: %i[index show new create] do
      resources :comments, only: :create
      resource :upvote, only: %i[create destroy]
    end

    # Discovery
    get "search", to: "search#index"
    get "leaderboard", to: "leaderboard#index"

    # Contribution / community
    resources :claims, only: %i[new create] do
      member { post :verify }
    end
    resources :reports, only: :create

    # Staff
    resources :moderation, only: %i[index update]
    namespace :admin do
      root to: "dashboard#overview"
      get "people", to: "dashboard#people"
      get "activity", to: "dashboard#activity"
      resources :users, only: :update
    end

    root to: "lures#index", as: :localized_root
  end
end
