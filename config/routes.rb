require 'sidekiq/web'

Rails.application.routes.draw do
  resources :consultations, only: [:new, :create, :show] do
    member do
      get :status
    end
  end
  get "consultations/status_demo"
  # Mount Sidekiq Web UI
  mount Sidekiq::Web => '/sidekiq'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # API routes for JavaScript widget
  namespace :api do
    namespace :v1 do
      # Chat endpoint for skin-related questions
      post 'chat/message', to: 'chat#message'
      
      # Photo analysis endpoint
      post 'chat/analyze_photo', to: 'chat#analyze_photo'
      
      # Get consultation status and results
      get 'chat/consultation/:id', to: 'chat#consultation_status'
      
      # Get product recommendations
      get 'chat/products', to: 'chat#products'
      
      # Handle preflight OPTIONS requests for CORS
      match '*path', to: 'chat#options', via: :options
    end
  end

  # Shop routes
  resources :shop, only: [:index]
  get "shop", to: "shop#index", as: :shop_index

  # Defines the root path route ("/")
  root "shop#index"
end
