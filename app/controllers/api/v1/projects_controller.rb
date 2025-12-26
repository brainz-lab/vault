module Api
  module V1
    class ProjectsController < ApplicationController
      before_action :authenticate_service_or_sdk!

      # POST /api/v1/projects/provision
      # Called by SDK to auto-provision a project
      def provision
        platform_project_id = params[:project_id]
        app_name = params[:app_name]

        unless platform_project_id.present?
          render json: { error: "project_id is required" }, status: :bad_request
          return
        end

        project = Project.find_or_initialize_by(platform_project_id: platform_project_id)

        if project.new_record?
          project.name = app_name || "Project #{platform_project_id.first(8)}"
          project.save!

          # Create default environments
          %w[development staging production].each_with_index do |env, idx|
            project.secret_environments.create!(
              name: env.titleize,
              slug: env,
              position: idx,
              locked: env == "production"
            )
          end

          # Set up inheritance: development inherits from staging, staging from production
          dev = project.secret_environments.find_by(slug: "development")
          staging = project.secret_environments.find_by(slug: "staging")

          dev.update!(inherits_from: "staging") if dev && staging
          staging.update!(inherits_from: "production") if staging
        end

        render json: {
          project_id: project.id,
          platform_project_id: project.platform_project_id,
          name: project.name,
          environments: project.secret_environments.pluck(:slug)
        }, status: project.previously_new_record? ? :created : :ok
      end

      # GET /api/v1/projects/lookup
      # Look up a project by platform_project_id
      def lookup
        platform_project_id = params[:project_id]

        project = Project.find_by(platform_project_id: platform_project_id)

        unless project
          render json: { error: "Project not found" }, status: :not_found
          return
        end

        render json: {
          project_id: project.id,
          platform_project_id: project.platform_project_id,
          name: project.name,
          environments: project.secret_environments.pluck(:slug)
        }
      end

      private

      def authenticate_service_or_sdk!
        # Accept service key for internal calls
        service_key = request.headers["X-Service-Key"]
        expected_key = ENV["SERVICE_KEY"] || "dev_service_key"

        if service_key.present? && ActiveSupport::SecurityUtils.secure_compare(service_key, expected_key)
          return true
        end

        # Accept API key for SDK calls
        api_key = request.headers["X-API-Key"] || request.headers["Authorization"]&.sub(/^Bearer /, "")

        if api_key.present?
          # Validate with Platform
          result = PlatformClient.validate_key(api_key)
          if result[:valid]
            return true
          end
        end

        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
