module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate!

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :bad_request

      protected

      def authenticate!
        @current_token = authenticate_token
        @current_project = @current_token&.project

        unless @current_project
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end

      def current_token
        @current_token
      end

      def current_environment
        return @current_environment if defined?(@current_environment)

        env_param = params[:environment] || request.headers["X-Vault-Environment"] || "development"
        @current_environment = current_project.secret_environments.find_by(slug: env_param)
      end

      def require_environment!
        unless current_environment
          render json: { error: "Environment not found" }, status: :not_found
        end
      end

      def require_permission!(permission)
        unless current_token.has_permission?(permission)
          render json: { error: "Forbidden: #{permission} permission required" }, status: :forbidden
        end
      end

      def log_access(action:, secret: nil, details: {})
        AuditLog.log_access(
          project: current_project,
          secret: secret,
          action: action,
          actor_type: "token",
          actor_id: current_token.id.to_s,
          actor_name: current_token.name,
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          details: details
        )
      end

      private

      def authenticate_token
        raw_token = extract_token
        return nil unless raw_token

        # Try to find by token prefix for efficient lookup
        prefix = raw_token.split("_").last&.first(8)
        return nil unless prefix

        AccessToken.active.where("token_prefix = ?", prefix).find_each do |token|
          if token.authenticate(raw_token)
            return token
          end
        end

        nil
      end

      def extract_token
        # Try Authorization header first (Bearer token)
        auth_header = request.headers["Authorization"]
        if auth_header&.start_with?("Bearer ")
          return auth_header[7..]
        end

        # Try X-API-Key header
        api_key = request.headers["X-API-Key"]
        return api_key if api_key.present?

        nil
      end

      def not_found(exception)
        render json: { error: exception.message }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { error: exception.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end

      def bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end
    end
  end
end
