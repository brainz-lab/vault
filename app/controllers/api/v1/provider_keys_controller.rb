module Api
  module V1
    class ProviderKeysController < BaseController
      before_action :require_project!

      # GET /api/v1/provider_keys
      # List available providers (doesn't expose actual keys)
      def index
        global_keys = ProviderKey.global_keys.active.select(:id, :name, :provider, :model_type, :priority, :global)
        project_keys = ProviderKey.for_project(current_project).active.select(:id, :name, :provider, :model_type, :priority, :global)

        render json: {
          global: global_keys.map { |k| key_summary(k) },
          project: project_keys.map { |k| key_summary(k) },
          available_providers: available_providers
        }
      end

      # GET /api/v1/provider_keys/bulk
      # Get all provider keys with decrypted values (for dotenv-style loading)
      # Returns one key per provider (highest priority)
      def bulk
        providers = available_providers
        keys = []

        providers.each do |provider|
          key = ProviderKey.resolve(
            project_id: current_project.id,
            provider: provider,
            model_type: "llm"
          )

          next unless key

          key.record_usage!
          keys << {
            provider: key.provider,
            model_type: key.model_type,
            key: key.decrypt,
            global: key.global?,
            name: key.name
          }
        end

        # Log access
        AuditLog.create!(
          project: current_project,
          action: "provider_keys_bulk",
          resource_type: "provider_key",
          resource_id: nil,
          resource_path: "/provider_keys/bulk",
          actor_type: "api",
          actor_id: current_project.api_key,
          actor_name: "API",
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          metadata: { providers: providers }
        )

        render json: { keys: keys }
      end

      # GET /api/v1/provider_keys/resolve
      # Get the decrypted key for a provider (the main endpoint Synapse will use)
      def resolve
        provider = params[:provider]
        model_type = params[:model_type] || "llm"

        unless provider.present?
          return render json: { error: "provider is required" }, status: :bad_request
        end

        key = ProviderKey.resolve(
          project_id: current_project.id,
          provider: provider,
          model_type: model_type
        )

        unless key
          return render json: {
            error: "No active #{provider} key found",
            available_providers: available_providers
          }, status: :not_found
        end

        log_key_access(key, "resolve")

        render json: {
          provider: key.provider,
          model_type: key.model_type,
          key: key.decrypt,
          global: key.global?,
          name: key.name,
          settings: key.settings
        }
      end

      # POST /api/v1/provider_keys
      # Create a new provider key (for automation)
      def create
        key = ProviderKey.create_encrypted(
          name: params[:name],
          provider: params[:provider],
          model_type: params[:model_type] || "llm",
          api_key: params[:api_key],
          global: params[:global] == true || params[:global] == "true",
          project: params[:global] ? nil : current_project,
          priority: params[:priority].to_i,
          settings: params[:settings] || {},
          metadata: params[:metadata] || {}
        )

        log_key_access(key, "create")

        render json: key_summary(key), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue ArgumentError => e
        render json: { error: e.message }, status: :bad_request
      end

      # DELETE /api/v1/provider_keys/:id
      def destroy
        key = find_key(params[:id])
        return render json: { error: "Key not found" }, status: :not_found unless key

        log_key_access(key, "delete")
        key.destroy!

        render json: { success: true }
      end

      # POST /api/v1/provider_keys/:id/deactivate
      def deactivate
        key = find_key(params[:id])
        return render json: { error: "Key not found" }, status: :not_found unless key

        key.deactivate!
        log_key_access(key, "deactivate")

        render json: key_summary(key)
      end

      # POST /api/v1/provider_keys/:id/activate
      def activate
        key = find_key(params[:id])
        return render json: { error: "Key not found" }, status: :not_found unless key

        key.activate!
        log_key_access(key, "activate")

        render json: key_summary(key)
      end

      private

      def find_key(id)
        # Can access global keys or project-specific keys
        ProviderKey.where("global = ? OR project_id = ?", true, current_project.id).find_by(id: id)
      end

      def key_summary(key)
        {
          id: key.id,
          name: key.name,
          provider: key.provider,
          model_type: key.model_type,
          global: key.global?,
          active: key.active?,
          priority: key.priority,
          key_prefix: key.key_prefix,
          last_used_at: key.last_used_at,
          usage_count: key.usage_count
        }
      end

      def available_providers
        keys = ProviderKey.where("global = ? OR project_id = ?", true, current_project.id).active
        keys.distinct.pluck(:provider)
      end

      def log_key_access(key, action)
        AuditLog.create!(
          project: current_project,
          action: "provider_key_#{action}",
          resource_type: "provider_key",
          resource_id: key.id,
          resource_path: "/provider_keys/#{key.id}",
          actor_type: "api",
          actor_id: current_project.api_key,
          actor_name: "API",
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          metadata: { provider: key.provider, global: key.global? }
        )
      end
    end
  end
end
