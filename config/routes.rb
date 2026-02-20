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
  get "/pending", to: "access#pending", as: :pending

  # Payments (Stripe Checkout)
  get "/billing", to: "payments#billing", as: :billing
  post "/payments/select_plan", to: "payments#select_plan", as: :payments_select_plan
  get "/payments/confirm", to: "payments#confirm", as: :payments_confirm
  post "/payments/checkout", to: "payments#checkout", as: :payments_checkout
  get "/payments/success", to: "payments#success", as: :payments_success
  get "/payments/cancel", to: "payments#cancel", as: :payments_cancel
  post "/payments/portal", to: "payments#portal", as: :payments_portal
  get "/payments/status", to: "payments#status", as: :payments_status

  # Webhooks
  post "/webhooks/stripe", to: "webhooks#stripe", as: :stripe_webhook

  namespace :google_ads do
    get "auth/start", to: "connections#start"
    get "auth/callback", to: "connections#callback"
    get "auth/select_plan", to: "connections#select_plan", as: :select_plan
    post "auth/select_plan", to: "connections#save_plan_selection", as: :save_plan
    get "auth/select_accounts", to: "connections#select_active_accounts", as: :select_active_accounts
    post "auth/select_accounts", to: "connections#save_active_accounts", as: :save_active_accounts
    get "auth/select", to: "connections#select_account", as: :select_account
    post "auth/select", to: "connections#save_account_selection"
    post "auth/switch_customer", to: "connections#switch_customer", as: :switch_customer
    delete "auth/disconnect/:id", to: "connections#destroy", as: :disconnect
    # Plan management
    get "plan/change", to: "connections#change_plan", as: :change_plan
    post "plan/change", to: "connections#save_change_plan", as: :save_change_plan
  end

  namespace :api do
    namespace :google_ads do
      get "customers", to: "customers#index"
      post "customers/refresh", to: "customers#refresh"
      post "customers/select", to: "customers#select"
      post "customers/fetch_names", to: "customers#fetch_names"

      # Customer names management
      patch "customers/:customer_id/name", to: "customer_names#update"
      post "customers/names/bulk_update", to: "customer_names#bulk_update"
      post "customers/names/smart_fetch", to: "customer_names#smart_fetch"

      get "campaigns", to: "campaigns#index"
      get "campaign_locations", to: "campaigns#locations"
    end

    resources :leads, only: [ :index ] do
      resources :conversations, only: [ :index ], module: :leads
      member do
        get :stored_feedback, to: "leads/stored_feedback#show"
        post :feedback, to: "leads/lead_feedback#create"
      end
      collection do
        post :bulk_feedback, to: "leads/bulk_lead_feedback#create"
      end
    end

    # State selections management
    get "state_selections", to: "state_selections#index"
    post "state_selections", to: "state_selections#update"
    delete "state_selections", to: "state_selections#clear"

    # Location search with state filtering
    post "location_search", to: "location_search#search"

    get "geo_targets/search", to: "geo_targets#search"
    post "geo_targets/update", to: "geo_targets#update"
  end

  # Admin area
  namespace :admin do
    root to: "dashboard#index"
    resources :users, only: [ :index, :show ] do
      member do
        patch :toggle_admin
        patch :toggle_allowed
      end
    end
    resources :subscriptions, only: [ :index, :show ]
    resources :activity_logs, only: [ :index ]
    resources :plans, only: [ :index ]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
