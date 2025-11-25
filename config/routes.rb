Rails.application.routes.draw do
  devise_for :users

  root "marketing/landing#show"
  get "/dashboard", to: "dashboard#show"
  get "/dashboard/activity_log", to: "dashboard#activity_log"
  get "/dashboard/account", to: "dashboard#account"
  get "/dashboard/leads", to: "dashboard#leads"

  resources :leads, only: [:index, :show]

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
    end

    resources :leads, only: [:index] do
      resources :conversations, only: [:index], module: :leads
      member do
        post :feedback, to: "leads/lead_feedback#create"
      end
      collection do
        post :bulk_feedback, to: "leads/bulk_lead_feedback#create"
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
