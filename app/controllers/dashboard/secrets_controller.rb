module Dashboard
  class SecretsController < BaseController
    before_action :require_project!
    before_action :load_environments, only: [ :index ]
    before_action :set_environment
    before_action :set_secret, only: [ :show, :edit, :update, :destroy, :history, :rollback, :generate_otp ]

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

      # Filter by secret type
      if params[:type].present?
        secrets_scope = secrets_scope.where(secret_type: params[:type])
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

        # Handle credential with OTP
        if @secret.otp_enabled? && params[:secret][:otp_secret].present?
          @secret.set_credential_with_otp(
            @environment,
            username: @secret.username,
            password: params[:secret][:value],
            otp_secret: params[:secret][:otp_secret],
            otp_type: @secret.secret_type == "hotp" ? "hotp" : "totp",
            otp_algorithm: @secret.otp_algorithm || "sha1",
            otp_digits: @secret.otp_digits || 6,
            otp_period: @secret.otp_period || 30,
            otp_issuer: @secret.otp_issuer,
            user: nil,
            note: "Created via dashboard"
          )
        elsif @secret.credential?
          @secret.save!
          if params[:secret][:value].present?
            @secret.set_credential(
              @environment,
              username: @secret.username,
              password: params[:secret][:value],
              user: nil,
              note: "Created via dashboard"
            )
          end
        else
          @secret.save!
          if params[:secret][:value].present?
            @secret.set_value(@environment, params[:secret][:value], user: nil, note: "Created via dashboard")
          end
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

        # Handle credential with OTP
        if @secret.otp_enabled? && params[:secret][:otp_secret].present?
          @secret.set_credential_with_otp(
            @environment,
            username: @secret.username,
            password: params[:secret][:value],
            otp_secret: params[:secret][:otp_secret],
            otp_type: @secret.secret_type == "hotp" ? "hotp" : "totp",
            otp_algorithm: @secret.otp_algorithm || "sha1",
            otp_digits: @secret.otp_digits || 6,
            otp_period: @secret.otp_period || 30,
            otp_issuer: @secret.otp_issuer,
            user: nil,
            note: params[:secret][:note]
          )
        elsif @secret.credential? && params[:secret][:value].present?
          @secret.set_credential(
            @environment,
            username: @secret.username,
            password: params[:secret][:value],
            user: nil,
            note: params[:secret][:note]
          )
        elsif params[:secret][:value].present?
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

    def generate_otp
      unless @secret.otp_enabled?
        return render json: { error: "Secret does not support OTP" }, status: :unprocessable_entity
      end

      otp_result = @secret.generate_otp(@environment)

      log_action("generate_otp", details: { otp_type: @secret.secret_type })

      render json: {
        code: otp_result[:code],
        expires_at: otp_result[:expires_at]&.iso8601,
        remaining_seconds: otp_result[:remaining_seconds],
        counter: otp_result[:counter]
      }
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
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
      params.require(:secret).permit(
        :key, :description, :secret_folder_id, :rotation_interval_days,
        :secret_type, :username, :otp_algorithm, :otp_digits, :otp_period, :otp_issuer,
        tags: {}
      )
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
