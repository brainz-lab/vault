module Api
  module V1
    class SecretsController < BaseController
      # Note: write/admin permission checks are done inline in actions
      before_action :require_environment!, only: [ :show, :create, :update, :rollback ]
      before_action :set_secret, only: [ :show, :update, :destroy, :versions, :rollback ]

      # GET /api/v1/secrets
      def index
        secrets = current_project.secrets.active

        # Filter by folder if provided
        if params[:folder].present?
          folder = current_project.secret_folders.find_by(path: params[:folder])
          secrets = secrets.in_folder(folder) if folder
        end

        # Filter by tag if provided
        if params[:tag].present?
          tag_key, tag_value = params[:tag].split(":")
          secrets = secrets.with_tag(tag_key, tag_value)
        end

        log_access(action: "list_secrets", details: { count: secrets.count })

        render json: {
          secrets: secrets.map { |s| secret_summary(s) },
          total: secrets.count
        }
      end

      # GET /api/v1/secrets/:key
      def show
        value = current_environment.resolve_value(@secret)

        log_access(
          action: "read_secret",
          secret: @secret,
          details: { environment: current_environment.slug }
        )

        render json: {
          key: @secret.key,
          path: @secret.path,
          value: value,
          environment: current_environment.slug,
          version: @secret.current_version_number,
          updated_at: @secret.updated_at
        }
      end

      # POST /api/v1/secrets
      def create
        return unless require_permission!("write")

        @secret = current_project.secrets.find_or_initialize_by(key: secret_params[:key])
        @secret.attributes = secret_params.except(:value)

        ActiveRecord::Base.transaction do
          @secret.save!

          if params[:value].present?
            @secret.set_value(
              current_environment,
              params[:value],
              user: nil,
              note: params[:note]
            )
          end
        end

        log_access(
          action: @secret.previously_new_record? ? "create_secret" : "update_secret",
          secret: @secret,
          details: { environment: current_environment.slug }
        )

        render json: {
          key: @secret.key,
          path: @secret.path,
          environment: current_environment.slug,
          version: @secret.current_version_number
        }, status: :created
      end

      # PUT/PATCH /api/v1/secrets/:key
      def update
        return unless require_permission!("write")

        ActiveRecord::Base.transaction do
          @secret.update!(secret_params.except(:value, :key))

          if params[:value].present?
            @secret.set_value(
              current_environment,
              params[:value],
              user: nil,
              note: params[:note]
            )
          end
        end

        log_access(
          action: "update_secret",
          secret: @secret,
          details: { environment: current_environment.slug }
        )

        render json: {
          key: @secret.key,
          path: @secret.path,
          environment: current_environment.slug,
          version: @secret.current_version_number
        }
      end

      # DELETE /api/v1/secrets/:key
      def destroy
        return unless require_permission!("admin")

        @secret.archive!

        log_access(action: "archive_secret", secret: @secret)

        head :no_content
      end

      # GET /api/v1/secrets/:key/versions
      def versions
        versions = @secret.versions
                          .order(version: :desc)
                          .limit(params[:limit] || 20)

        log_access(
          action: "list_versions",
          secret: @secret,
          details: { count: versions.count }
        )

        render json: {
          key: @secret.key,
          versions: versions.map do |v|
            {
              version: v.version,
              environment: v.secret_environment&.slug,
              created_at: v.created_at,
              created_by: v.created_by || "system",
              note: v.change_note
            }
          end
        }
      end

      # POST /api/v1/secrets/:key/rollback
      def rollback
        return unless require_permission!("write")

        version_number = params[:version].to_i
        target_version = @secret.versions.find_by!(
          version: version_number,
          secret_environment: current_environment
        )

        # Create new version with the old value
        @secret.set_value(
          current_environment,
          target_version.decrypt,
          user: nil,
          note: "Rollback to version #{version_number}"
        )

        log_access(
          action: "rollback_secret",
          secret: @secret,
          details: { from_version: version_number, environment: current_environment.slug }
        )

        render json: {
          key: @secret.key,
          rolled_back_to: version_number,
          new_version: @secret.current_version_number
        }
      end

      private

      def set_secret
        @secret = current_project.secrets.active.find_by!(key: params[:key])
      end

      def secret_params
        params.permit(:key, :path, :description, :secret_folder_id, :rotation_interval_days, tags: {})
      end

      def secret_summary(secret)
        {
          key: secret.key,
          path: secret.path,
          description: secret.description,
          has_value: secret.versions.exists?,
          version: secret.current_version_number,
          tags: secret.tags,
          updated_at: secret.updated_at
        }
      end
    end
  end
end
