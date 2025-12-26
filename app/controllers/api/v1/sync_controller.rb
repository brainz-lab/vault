module Api
  module V1
    class SyncController < BaseController
      before_action :require_environment!

      # GET /api/v1/sync/export
      # Export all secrets for an environment
      def export
        format = params[:format]&.to_sym || :json
        service_filter = params[:service]
        folder_filter = params[:folder]

        resolver = SecretResolver.new(current_project, current_environment)

        secrets = if service_filter.present?
          resolver.resolve_for_service(service_filter)
        elsif folder_filter.present?
          resolver.resolve_by_folder(folder_filter)
        else
          resolver.resolve_all
        end

        log_access(
          action: "export_secrets",
          details: {
            environment: current_environment.slug,
            format: format,
            count: secrets.count
          }
        )

        case format
        when :dotenv
          render plain: EnvFileGenerator.new(current_environment).generate(format: :dotenv),
                 content_type: "text/plain"
        when :shell
          render plain: EnvFileGenerator.new(current_environment).generate(format: :shell),
                 content_type: "text/plain"
        when :yaml
          render plain: secrets.to_yaml, content_type: "text/yaml"
        else
          render json: { secrets: secrets }
        end
      end

      # POST /api/v1/sync/import
      # Import secrets from .env or JSON
      def import
        require_permission!("write")

        content = params[:content]
        format = params[:format]&.to_sym || :dotenv

        unless content.present?
          render json: { error: "Content is required" }, status: :bad_request
          return
        end

        importer = SecretImporter.new(current_project, current_environment)

        result = case format
        when :json
          importer.import_from_json(content)
        else
          importer.import_from_env_file(content)
        end

        log_access(
          action: "import_secrets",
          details: {
            environment: current_environment.slug,
            format: format,
            imported: result[:imported].count,
            errors: result[:errors].count
          }
        )

        render json: {
          imported: result[:imported],
          errors: result[:errors],
          environment: current_environment.slug
        }
      end

      # POST /api/v1/sync/pull
      # Pull secrets that have changed since a timestamp
      def pull
        since = params[:since] ? Time.parse(params[:since]) : 1.hour.ago

        secrets = current_project.secrets.active.where("updated_at > ?", since)

        log_access(
          action: "pull_secrets",
          details: {
            environment: current_environment.slug,
            since: since,
            count: secrets.count
          }
        )

        render json: {
          secrets: secrets.map do |secret|
            value = current_environment.resolve_value(secret)
            {
              key: secret.key,
              path: secret.path,
              value: value,
              version: secret.current_version_number,
              updated_at: secret.updated_at
            }
          end,
          timestamp: Time.current.iso8601
        }
      end

      # POST /api/v1/sync/push
      # Push multiple secrets at once
      def push
        require_permission!("write")

        secrets_data = params[:secrets]

        unless secrets_data.is_a?(Array)
          render json: { error: "Secrets must be an array" }, status: :bad_request
          return
        end

        results = { created: [], updated: [], errors: [] }

        secrets_data.each do |secret_data|
          key = secret_data[:key]
          value = secret_data[:value]

          begin
            secret = current_project.secrets.find_or_initialize_by(key: key)
            was_new = secret.new_record?
            secret.save! if was_new

            secret.set_value(current_environment, value, user: nil, note: "Pushed via API")

            if was_new
              results[:created] << key
            else
              results[:updated] << key
            end
          rescue => e
            results[:errors] << { key: key, error: e.message }
          end
        end

        log_access(
          action: "push_secrets",
          details: {
            environment: current_environment.slug,
            created: results[:created].count,
            updated: results[:updated].count,
            errors: results[:errors].count
          }
        )

        render json: results
      end
    end
  end
end
