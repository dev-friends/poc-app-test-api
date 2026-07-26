Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  resources :test_runs, only: [:index, :show, :create] do
    member { get :results }
    collection { get :status }
  end

  scope path: "opencode" do
    resources :runs, only: [:index, :show, :create], controller: "opencode_runs"
    resources :sessions, only: [:index, :destroy], controller: "opencode_sessions"
    get "models", to: "opencode#models"
    get "agents", to: "opencode#agents"
  end
end
