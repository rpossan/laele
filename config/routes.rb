Rails.application.routes.draw do
  devise_for :users

  # Locale switching
  get "/locale/:locale", to: "locales#update", as: :set_locale

  root "marketing/landing#show"
  get "/dashboard", to: "dashboard#show"
  get "/dashboard/activity_log", to: "dashboard#activity_log"
  get "/dashboard/account", to: "dashboard#account"
  get "/dashboard/leads", to: "dashboard#leads"
  get "/dashboard/campaigns", to: "dashboard#campaigns"

  resources :leads, only: [ :index, :show ]
  get "/pricing", to: "marketing/pricing#show"
  get "/privacy", to: "legal#privacy", as: :privacy

  namespace :google_ads do
    get "auth/start", to: "connections#start"
    get "auth/callback", to: "connections#callback"
    get "auth/select", to: "connections#select_account", as: :select_account
    post "auth/select", to: "connections#save_account_selection"
    delete "auth/disconnect/:id", to: "connections#destroy", as: :disconnect
  end

  namespace :api do
    namespace :google_ads do
      get "customers", to: "customers#index"
      post "customers/refresh", to: "customers#refresh"
      post "customers/select", to: "customers#select"
      get "campaigns", to: "campaigns#index"
      get "campaign_locations", to: "campaigns#locations"
    end

    resources :leads, only: [ :index ] do
      resources :conversations, only: [ :index ], module: :leads
      member do
        post :feedback, to: "leads/lead_feedback#create"
      end
      collection do
        post :bulk_feedback, to: "leads/bulk_lead_feedback#create"
      end
    end

    get "geo_targets/search", to: "geo_targets#search"
    post "geo_targets/update", to: "geo_targets#update"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
