Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # === Dashboard (main entry point) ===
  root "dashboard#index"
  get "dashboard", to: "dashboard#index"
  get "dashboard/grid_map", to: "dashboard#grid_map"
  get "dashboard/profitability", to: "dashboard#profitability"

  # === Provider Onboarding ===
  resources :providers, only: [:index, :show, :new, :create, :edit, :update] do
    member do
      get :onboard, as: :onboard
      post :register_hardware
      post :benchmark
      post :onboard_complete
    end
  end

  # === B2B/B2C: Workloads ===
  resources :workloads, only: [:index, :show, :new, :create] do
    member do
      post :route
      post :pause
      post :reroute
      post :complete
    end
  end

  # === Compute Nodes ===
  resources :compute_nodes, only: [:index, :show, :new, :create, :edit, :update]

  # === Grid States (live energy data) ===
  resources :grid_states, only: [:index, :show] do
    collection do
      get :live_map
      post :ingest
    end
  end

  # === Curtailment Events ===
  resources :curtailment_events, only: [:index, :show] do
    member do
      post :trigger_alert
    end
  end

  # === Sustainability Dashboard ===
  get "sustainability", to: "sustainability#dashboard", as: :sustainability_dashboard

  # === Admin — Crusoe Override & Global Controls ===
  get "admin", to: "admin#dashboard", as: :admin_dashboard
  post "admin/override_routing", to: "admin#override_routing", as: :admin_override_routing
  get "admin/heatmap", to: "admin#heatmap_data", as: :admin_heatmap
  post "admin/settle", to: "admin#settle", as: :admin_settle
  get "admin/health", to: "admin#health_overview", as: :admin_health
  get "admin/gpu_slices", to: "admin#gpu_slices", as: :admin_gpu_slices
  post "admin/manage_slices", to: "admin#manage_slices", as: :admin_manage_slices

  # === API namespace for external integrations ===
  namespace :api do
    namespace :v1 do
      # Core resources
      resources :workloads, only: [:index, :show, :create] do
        member do
          post :route
          post :complete
        end
      end
      resources :compute_nodes, only: [:index, :show, :create, :update]
      resources :grid_states, only: [:index]

      # Dashboard aggregate endpoint
      get "dashboard", to: "dashboard#index"

      # Marketplace
      get "marketplace", to: "marketplace#index"
      post "marketplace/:id/deploy", to: "marketplace#deploy"

      # GPU Telemetry
      get "telemetry", to: "telemetry#index"

      # Energy Heatmap
      get "heatmap", to: "heatmap#index"

      # Sustainability & Financials
      get "sustainability", to: "sustainability#index"

      # Admin & Crusoe Override
      get "admin", to: "admin#index"
      post "admin/declare_waste_event", to: "admin#declare_waste_event"
      post "admin/override_routing", to: "admin#override_routing"

      # Provider Onboarding
      post "onboarding/register", to: "onboarding#register"
      post "onboarding/benchmark", to: "onboarding#benchmark"

      # Analytics
      get "profitability", to: "analytics#profitability"
      get "carbon_report", to: "analytics#carbon_report"
    end
  end

  # === Demo controls ===
  namespace :demo do
    post "simulate_grid_cycle", to: "simulation#grid_cycle"
    post "simulate_workload", to: "simulation#create_workload"
    post "simulate_reroute", to: "simulation#trigger_reroute"
    post "simulate_curtailment", to: "simulation#trigger_curtailment"
    post "simulate_completion", to: "simulation#complete_workloads"
    post "simulate_health_migration", to: "simulation#trigger_health_migration"
    post "simulate_slicing", to: "simulation#trigger_slicing"
  end
end
