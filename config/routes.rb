Rails.application.routes.draw do
  # API v1
  namespace :api do
    namespace :v1 do
      # Secrets - flat routing with key param
      resources :secrets, param: :key, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          get :versions
          post :rollback
          get :credential
          post "otp/generate", to: "secrets#generate_otp"
          post "otp/verify", to: "secrets#verify_otp"
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

      # Connectors
      resources :connectors, only: [ :index, :show ] do
        member { get :actions }
      end
      resources :connector_credentials, only: [ :index, :create, :show, :destroy ] do
        member { post :verify }
      end
      resources :connector_connections, only: [ :index, :create, :show, :update, :destroy ] do
        member do
          post :test
          post :execute
        end
        collection { get :mcp_tools }
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
      post "projects/:platform_project_id/archive", to: "projects#archive"
      post "projects/:platform_project_id/unarchive", to: "projects#unarchive"
      post "projects/:platform_project_id/purge", to: "projects#purge"
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
        post :regenerate_mcp_token
        get :ssh_keys
      end

      resources :secrets do
        member do
          get :history
          post :rollback
          post :generate_otp
        end
      end

      resources :environments
      resources :access_tokens do
        member do
          post :regenerate
        end
      end
      resources :audit_logs, only: [ :index, :show ]

      resources :connectors, only: [ :index, :show ] do
        member { get :actions }
      end
      resources :connector_credentials, only: [ :index, :new, :create, :destroy ] do
        member { post :verify }
      end
      resources :connector_connections, only: [ :index, :new, :create, :show, :destroy ] do
        member do
          post :test
          post :execute
        end
      end
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
