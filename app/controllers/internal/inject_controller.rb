module Internal
  class InjectController < ApplicationController
    before_action :authenticate_service!

    # POST /internal/inject
    # Called by Synapse during deployments to inject secrets
    def create
      project = Project.find_by!(platform_project_id: params[:project_id])
      environment = project.secret_environments.find_by!(slug: params[:environment])

      resolver = SecretResolver.new(project, environment)

      # Filter by service if provided
      secrets = if params[:service].present?
        resolver.resolve_for_service(params[:service])
      else
        resolver.resolve_all
      end

      # Apply template resolution if provided
      if params[:template].present?
        rendered = resolver.resolve_with_references(params[:template])
        render plain: rendered, content_type: "text/plain"
        return
      end

      # Return in requested format
      format = params[:format]&.to_sym || :json

      case format
      when :dotenv
        render plain: to_dotenv(secrets), content_type: "text/plain"
      when :shell
        render plain: to_shell(secrets), content_type: "text/plain"
      when :kubernetes
        render json: to_kubernetes_secret(secrets, params[:secret_name] || "app-secrets")
      else
        render json: { env: secrets }
      end
    end

    # GET /internal/health
    def health
      render json: { status: "ok", service: "vault" }
    end

    private

    def authenticate_service!
      service_key = request.headers["X-Service-Key"]
      expected_key = ENV["SERVICE_KEY"] || "dev_service_key"

      unless ActiveSupport::SecurityUtils.secure_compare(service_key.to_s, expected_key)
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end

    def to_dotenv(secrets)
      secrets.map { |k, v| "#{k}=#{escape_value(v)}" }.join("\n")
    end

    def to_shell(secrets)
      secrets.map { |k, v| "export #{k}=#{Shellwords.escape(v)}" }.join("\n")
    end

    def to_kubernetes_secret(secrets, name)
      {
        apiVersion: "v1",
        kind: "Secret",
        metadata: { name: name },
        type: "Opaque",
        data: secrets.transform_values { |v| Base64.strict_encode64(v) }
      }
    end

    def escape_value(value)
      return '""' if value.nil? || value.empty?

      if value.match?(/[\s#"'$\\]/) || value.include?("\n")
        escaped = value.gsub("\\", "\\\\").gsub('"', '\\"').gsub("\n", '\\n')
        "\"#{escaped}\""
      else
        value
      end
    end
  end
end
