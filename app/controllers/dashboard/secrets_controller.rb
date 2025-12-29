module Dashboard
  class SecretsController < BaseController
    before_action :require_project!
    before_action :load_environments, only: [:index]
    before_action :set_environment
    before_action :set_secret, only: [:show, :edit, :update, :destroy, :history, :rollback]

    def index
      # Build secrets query with filters
      # Use @current_project directly to avoid method call overhead
      secrets_scope = @current_project.secrets.active

      if params[:folder].present?
        folder = @current_project.secret_folders.find_by(path: params[:folder])
        secrets_scope = secrets_scope.in_folder(folder) if folder
      end

      if params[:search].present?
        secrets_scope = secrets_scope.where("key ILIKE ?", "%#{params[:search]}%")
      end

      # Eager load secrets with versions AND their secret_environments to avoid N+1
      # The versions association is needed for current_version_number
      # The secret_environment on versions is needed if version info is displayed
      @secrets = secrets_scope
                   .includes(versions: :secret_environment)
                   .order(:key)
                   .load

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def show
      @value = @environment.resolve_value(@secret)
      @versions = @secret.versions
                         .where(secret_environment: @environment)
                         .order(version: :desc)
                         .limit(10)
    end

    def new
      @secret = @current_project.secrets.build
    end

    def create
      @secret = @current_project.secrets.find_or_initialize_by(key: secret_params[:key])

      ActiveRecord::Base.transaction do
        @secret.attributes = secret_params.except(:value)
        @secret.save!

        if params[:secret][:value].present?
          @secret.set_value(@environment, params[:secret][:value], user: nil, note: "Created via dashboard")
        end
      end

      log_action("create_secret")
      redirect_to dashboard_project_secret_path(@current_project, @secret), notice: "Secret created"
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
      redirect_to dashboard_project_secret_path(@current_project, @secret), notice: "Secret updated"
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def destroy
      @secret.archive!
      log_action("archive_secret")
      redirect_to dashboard_project_secrets_path(@current_project), notice: "Secret archived"
    end

    def history
      @versions = @secret.versions
                         .where(secret_environment: @environment)
                         .order(version: :desc)
    end

    def rollback
      version_number = params[:version].to_i
      target_version = @secret.versions.find_by!(
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
      redirect_to dashboard_project_secret_path(@current_project, @secret), notice: "Rolled back to version #{version_number}"
    end

    private

    def load_environments
      # Eager load all environments for dropdown (used by index action)
      # Use @current_project directly to avoid method call overhead
      @environments = @current_project.secret_environments.order(:position).load
    end

    def set_environment
      slug = params[:environment] || session[:current_environment] || "development"
      # Reuse @environments if already loaded (avoids duplicate query)
      # Use @current_project directly to avoid method call overhead
      if @environments
        @environment = @environments.find { |e| e.slug == slug } || @environments.first
      else
        @environment = @current_project.secret_environments.find_by(slug: slug) ||
                       @current_project.secret_environments.first
      end
      session[:current_environment] = @environment&.slug
    end

    def set_secret
      @secret = @current_project.secrets.find(params[:id])
    end

    def secret_params
      params.require(:secret).permit(:key, :description, :secret_folder_id, :rotation_interval_days, tags: {})
    end

    def log_action(action, details: {})
      AuditLog.log_access(
        project: @current_project,
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
