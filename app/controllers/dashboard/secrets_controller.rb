module Dashboard
  class SecretsController < BaseController
    before_action :require_project!
    before_action :set_environment
    before_action :set_secret, only: [:show, :edit, :update, :destroy, :history, :rollback]

    def index
      @secrets = current_project.secrets.active.order(:key)

      if params[:folder].present?
        folder = current_project.secret_folders.find_by(path: params[:folder])
        @secrets = @secrets.in_folder(folder) if folder
      end

      if params[:search].present?
        @secrets = @secrets.where("key ILIKE ?", "%#{params[:search]}%")
      end

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def show
      @value = @environment.resolve_value(@secret)
      @versions = @secret.secret_versions
                         .where(secret_environment: @environment)
                         .order(version: :desc)
                         .limit(10)
    end

    def new
      @secret = current_project.secrets.build
    end

    def create
      @secret = current_project.secrets.find_or_initialize_by(key: secret_params[:key])

      ActiveRecord::Base.transaction do
        @secret.attributes = secret_params.except(:value)
        @secret.save!

        if params[:secret][:value].present?
          @secret.set_value(@environment, params[:secret][:value], user: nil, note: "Created via dashboard")
        end
      end

      log_action("create_secret")
      redirect_to dashboard_project_secret_path(current_project, @secret), notice: "Secret created"
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit
      @value = @environment.resolve_value(@secret)
    end

    def update
      ActiveRecord::Base.transaction do
        @secret.update!(secret_params.except(:value))

        if params[:secret][:value].present?
          @secret.set_value(@environment, params[:secret][:value], user: nil, note: params[:secret][:note])
        end
      end

      log_action("update_secret")
      redirect_to dashboard_project_secret_path(current_project, @secret), notice: "Secret updated"
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @secret.archive!
      log_action("archive_secret")
      redirect_to dashboard_project_secrets_path(current_project), notice: "Secret archived"
    end

    def history
      @versions = @secret.secret_versions
                         .where(secret_environment: @environment)
                         .order(version: :desc)
    end

    def rollback
      version_number = params[:version].to_i
      target_version = @secret.secret_versions.find_by!(
        version: version_number,
        secret_environment: @environment
      )

      @secret.set_value(
        @environment,
        target_version.decrypt,
        user: nil,
        note: "Rollback to version #{version_number}"
      )

      log_action("rollback_secret", details: { from_version: version_number })
      redirect_to dashboard_project_secret_path(current_project, @secret), notice: "Rolled back to version #{version_number}"
    end

    private

    def set_environment
      slug = params[:environment] || session[:current_environment] || "development"
      @environment = current_project.secret_environments.find_by(slug: slug) ||
                     current_project.secret_environments.first
      session[:current_environment] = @environment&.slug
    end

    def set_secret
      @secret = current_project.secrets.find(params[:id])
    end

    def secret_params
      params.require(:secret).permit(:key, :description, :folder_id, :expires_at, :rotation_days, tags: {})
    end

    def log_action(action, details: {})
      AuditLog.log_access(
        project: current_project,
        secret: @secret,
        action: action,
        actor_type: "user",
        actor_id: current_user[:id],
        actor_name: current_user[:name] || current_user[:email],
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        details: details.merge(environment: @environment.slug)
      )
    end
  end
end
