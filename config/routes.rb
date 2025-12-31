Rails.application.routes.draw do
  # API v1
  namespace :api do
    namespace :v1 do
      # Secrets - flat routing with key param
      resources :secrets, param: :key, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          get :versions
          post :rollback
        end
      end

      # Environments
      resources :environments, param: :slug, only: [ :index, :show, :create, :update, :destroy ]

      # Sync endpoints
      get "sync/export", to: "sync#export"
      post "sync/import", to: "sync#import"
      post "sync/pull", to: "sync#pull"
      post "sync/push", to: "sync#push"

      # Folder management
      resources :folders, param: :path, path: "folders/*path", constraints: { path: /.*/ }

      # Access management
      resources :access_tokens do
        member do
          post :regenerate
        end
      end
      resources :access_policies

      # Audit logs (read-only)
      resources :audit_logs, only: [ :index ] do
        collection do
          get "secret/:key", to: "audit_logs#for_secret"
        end
      end

      # Provider keys (API keys for LLMs, etc.)
      resources :provider_keys, only: [ :index, :create, :destroy ] do
        collection do
          get :resolve
          get :bulk
        end
        member do
          post :activate
          post :deactivate
        end
      end

      # Project provisioning (internal API for SDK auto-setup)
      post "projects/provision", to: "projects#provision"
      get "projects/lookup", to: "projects#lookup"
    end
  end

  # Internal endpoints (for deployment systems)
  namespace :internal do
    post "inject", to: "inject#create"
    get "health", to: "inject#health"
  end

  # MCP Server
  namespace :mcp do
    get "tools", to: "tools#index"
    post "tools/:name", to: "tools#call"
    post "rpc", to: "tools#rpc"
  end

  # Dashboard
  namespace :dashboard do
    # Global provider keys (not project-scoped)
    resources :provider_keys do
      member do
        post :toggle_active
      end
    end

    resources :projects do
      member do
        get :setup
        get :mcp_setup
      end

      resources :secrets do
        member do
          get :history
          post :rollback
        end
      end

      resources :environments
      resources :access_tokens do
        member do
          post :regenerate
        end
      end
      resources :audit_logs, only: [ :index, :show ]
    end

    root to: "projects#index"
  end

  # SSO from Platform
  get "sso/callback", to: "sso#callback"

  # Health check
  get "health", to: "health#show"
  get "up", to: ->(_) { [ 200, {}, [ "ok" ] ] }

  # WebSocket
  mount ActionCable.server => "/cable"

  root "dashboard/projects#index"
end
