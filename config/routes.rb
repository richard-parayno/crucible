# frozen_string_literal: true

Rails.application.routes.draw do
  get  "sign_in", to: "sessions#new", as: :sign_in
  post "sign_in", to: "sessions#create"
  get  "sign_up", to: "users#new", as: :sign_up
  post "sign_up", to: "users#create"

  resources :sessions, only: [:destroy]
  resource :users, only: [:destroy]

  namespace :identity do
    resource :email_verification, only: [:show, :create]
    resource :password_reset,     only: [:new, :edit, :create, :update]
  end

  get :dashboard, to: "dashboard#index"
  resource :system_check, only: %i[show]
  resources :agents, only: %i[index new create show]
  resources :codex_sessions, only: %i[index show], param: :session_id

  resources :workspaces, only: [] do
    resources :environment_variables, only: %i[create update destroy]

    resources :runtime_instances, only: [] do
      resources :agent_runs, only: %i[create]
      resources :environment_variables, only: %i[create update destroy]

      member do
        post :start
        post :stop
        post :restart
        post :check_health
      end
    end
  end

  namespace :settings do
    resource :profile, only: [:show, :update]
    resource :password, only: [:show, :update]
    resource :email, only: [:show, :update]
    resources :sessions, only: [:index]
    inertia :appearance
  end

  root "home#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  mount ActionCable.server => "/cable"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
