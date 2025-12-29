module Dashboard
  class ProviderKeysController < BaseController
    before_action :set_provider_key, only: [:show, :edit, :update, :destroy, :toggle_active]

    def index
      @global_keys = ProviderKey.global_keys.active.by_priority
      @project_keys = current_project ? ProviderKey.for_project(current_project).active.by_priority : []
      @all_keys = current_project ? ProviderKey.where("global = ? OR project_id = ?", true, current_project.id).by_priority : ProviderKey.global_keys.by_priority
    end

    def show
    end

    def new
      @provider_key = ProviderKey.new(
        global: params[:global] == "true",
        project: params[:global] == "true" ? nil : current_project
      )
    end

    def create
      is_global = provider_key_params[:global] == "1" || provider_key_params[:global] == true

      @provider_key = ProviderKey.create_encrypted(
        name: provider_key_params[:name],
        provider: provider_key_params[:provider],
        model_type: provider_key_params[:model_type] || "llm",
        api_key: params[:provider_key][:api_key],
        global: is_global,
        project: is_global ? nil : current_project,
        priority: provider_key_params[:priority].to_i,
        settings: {},
        metadata: {}
      )

      log_action("create_provider_key", resource: @provider_key)
      redirect_to dashboard_provider_keys_path(project_id: current_project&.id), notice: "Provider key created"
    rescue ActiveRecord::RecordInvalid => e
      @provider_key = ProviderKey.new(provider_key_params.except(:api_key))
      @provider_key.errors.merge!(e.record.errors)
      render :new, status: :unprocessable_entity
    rescue ArgumentError => e
      @provider_key = ProviderKey.new(provider_key_params.except(:api_key))
      @provider_key.errors.add(:api_key, e.message)
      render :new, status: :unprocessable_entity
    end

    def edit
    end

    def update
      # If new API key provided, re-encrypt
      if params[:provider_key][:api_key].present?
        encrypted_data = Encryption::Encryptor.encrypt(
          params[:provider_key][:api_key],
          project_id: @provider_key.project_id
        )
        @provider_key.encrypted_key = encrypted_data.ciphertext
        @provider_key.encryption_iv = encrypted_data.iv
        @provider_key.encryption_key_id = encrypted_data.key_id
        @provider_key.key_prefix = params[:provider_key][:api_key][0, 12]
      end

      @provider_key.assign_attributes(provider_key_params.except(:api_key))

      if @provider_key.save
        log_action("update_provider_key", resource: @provider_key)
        redirect_to dashboard_provider_keys_path(project_id: current_project&.id), notice: "Provider key updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @provider_key.destroy!
      log_action("delete_provider_key", resource: @provider_key)
      redirect_to dashboard_provider_keys_path(project_id: current_project&.id), notice: "Provider key deleted"
    end

    def toggle_active
      if @provider_key.active?
        @provider_key.deactivate!
        log_action("deactivate_provider_key", resource: @provider_key)
        notice = "Provider key deactivated"
      else
        @provider_key.activate!
        log_action("activate_provider_key", resource: @provider_key)
        notice = "Provider key activated"
      end

      redirect_to dashboard_provider_keys_path(project_id: current_project&.id), notice: notice
    end

    private

    def set_provider_key
      @provider_key = ProviderKey.find(params[:id])
    end

    def provider_key_params
      params.require(:provider_key).permit(:name, :provider, :model_type, :global, :priority, :expires_at)
    end

    def log_action(action, resource:)
      return unless current_project

      AuditLog.create!(
        project: current_project,
        action: action,
        resource_type: "provider_key",
        resource_id: resource.id,
        resource_path: "/provider_keys/#{resource.id}",
        actor_type: "user",
        actor_id: current_user[:id],
        actor_name: current_user[:name] || current_user[:email],
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        metadata: { provider: resource.provider, global: resource.global? }
      )
    end
  end
end
