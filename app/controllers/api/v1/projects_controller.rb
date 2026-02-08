# frozen_string_literal: true

module Api
  module V1
    class ProjectsController < ApplicationController
      before_action :authenticate_master_or_service_key!

      # POST /api/v1/projects/provision
      # Creates a new project or returns existing one, linked to Platform
      def provision
        # Accept both platform_project_id and project_id for backwards compatibility
        platform_project_id = params[:platform_project_id] || params[:project_id]
        name = params[:name] || params[:app_name]

        unless platform_project_id.present?
          render json: { error: "platform_project_id is required" }, status: :bad_request
          return
        end

        project = Project.find_or_initialize_by(platform_project_id: platform_project_id)

        if project.new_record?
          project.name = name || "Project #{platform_project_id.first(8)}"
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
        else
          # Update name if provided and project already exists
          project.update!(name: name) if name.present? && project.name != name
        end

        render json: {
          id: project.id,
          platform_project_id: project.platform_project_id,
          name: project.name,
          environments: project.secret_environments.pluck(:slug)
        }, status: project.previously_new_record? ? :created : :ok
      end

      # GET /api/v1/projects/lookup
      # Look up a project by platform_project_id
      def lookup
        # Accept both platform_project_id and project_id for backwards compatibility
        platform_project_id = params[:platform_project_id] || params[:project_id]

        project = Project.find_by(platform_project_id: platform_project_id)

        unless project
          render json: { error: "Project not found" }, status: :not_found
          return
        end

        render json: {
          id: project.id,
          platform_project_id: project.platform_project_id,
          name: project.name,
          environments: project.secret_environments.pluck(:slug)
        }
      end

      private

      def authenticate_master_or_service_key!
        # Accept master key for Platform sync
        master_key = request.headers["X-Master-Key"]
        expected_master = ENV["VAULT_MASTER_KEY"]

        if master_key.present? && expected_master.present? &&
           ActiveSupport::SecurityUtils.secure_compare(master_key, expected_master)
          return true
        end

        # Accept service key for internal calls
        service_key = request.headers["X-Service-Key"]
        expected_service = ENV["SERVICE_KEY"] || "dev_service_key"

        if service_key.present? && ActiveSupport::SecurityUtils.secure_compare(service_key, expected_service)
          return true
        end

        # Accept API key for SDK calls
        api_key = request.headers["X-API-Key"] || request.headers["Authorization"]&.sub(/^Bearer /, "")

        if api_key.present?
          result = PlatformClient.validate_key(api_key) rescue nil
          return true if result && result[:valid]
        end

        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
