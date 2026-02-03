module Dashboard
  class ProjectsController < BaseController
    # Skip set_current_project for actions that load their own project via set_project
    # This prevents duplicate Project.find queries (N+1 optimization)
    skip_before_action :set_current_project, only: [ :index, :new, :create, :show, :edit, :update, :destroy, :setup, :mcp_setup, :regenerate_mcp_token, :ssh_keys ]
    before_action :set_project, only: [ :show, :edit, :update, :destroy, :setup, :mcp_setup, :regenerate_mcp_token, :ssh_keys ]
    before_action :redirect_to_platform_in_production, only: [ :new, :create ]

    def index
      # In development or standalone mode, show all projects
      # Use scalar subqueries to load all counts in a single query (avoids N+1)
      # Note: In production, show all projects for now (multi-tenancy filtering TBD)
      base_scope = Project.all

      @projects = base_scope
        .select("projects.*")
        .select("(SELECT COUNT(*) FROM secrets WHERE secrets.project_id = projects.id AND secrets.archived = false) AS secrets_count")
        .select("(SELECT COUNT(*) FROM secret_environments WHERE secret_environments.project_id = projects.id) AS environments_count")
        .select("(SELECT COUNT(*) FROM access_tokens WHERE access_tokens.project_id = projects.id AND access_tokens.active = true AND access_tokens.revoked_at IS NULL AND (access_tokens.expires_at IS NULL OR access_tokens.expires_at > NOW())) AS tokens_count")
        .order(:name)
        .load  # Force eager load to prevent lazy evaluation in view
    end

    def show
      session[:current_project_id] = @project.id
      @environments = @project.secret_environments.order(:position)
      @recent_secrets = @project.secrets.active.order(updated_at: :desc).limit(10)
      @recent_logs = @project.audit_logs.order(created_at: :desc).limit(5)
    end

    def new
      @project = Project.new
    end

    def create
      @project = Project.new(project_params)

      if @project.save
        # Note: default environments are created by model callback
        redirect_to dashboard_project_path(@project), notice: "Project created successfully"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @project.update(project_params)
        redirect_to dashboard_project_path(@project), notice: "Project updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @project.destroy
      session.delete(:current_project_id)
      redirect_to dashboard_projects_path, notice: "Project deleted"
    end

    def setup
      @environments = @project.secret_environments.order(:position)
    end

    def mcp_setup
      @token = @project.access_tokens.active.find_by(name: "MCP Token")
      unless @token
        @token = @project.access_tokens.build(
          name: "MCP Token",
          permissions: [ "read", "write" ]  # Fixed: was 'scopes', removed non-existent 'description'
        )
        @token.save!
        @raw_token = @token.plain_token  # Access the token set by before_validation callback
      end
    end

    def regenerate_mcp_token
      # Revoke existing MCP token
      old_token = @project.access_tokens.active.find_by(name: "MCP Token")
      old_token&.revoke!

      # Create new token
      @token = @project.access_tokens.create!(
        name: "MCP Token",
        permissions: [ "read", "write" ]
      )
      @raw_token = @token.plain_token

      redirect_to mcp_setup_dashboard_project_path(@project), notice: "MCP token regenerated"
    end

    def ssh_keys
      @client_keys = @project.ssh_client_keys.active.order(:name)
      @server_keys = @project.ssh_server_keys.active.order(:hostname)
      @connections = @project.ssh_connections.active.includes(:ssh_client_key, :jump_connection).order(:name)
    end

    private

    def set_project
      # Eager load secret_environments for layout navigation sidebar
      @project = Project.includes(:secret_environments).find(params[:id])
      @current_project = @project  # Reuse for layout navigation (avoids duplicate query)
    end

    def project_params
      params.require(:project).permit(:name, :platform_project_id)
    end

    def redirect_to_platform_in_production
      return unless Rails.env.production?

      platform_url = ENV.fetch("BRAINZLAB_PLATFORM_EXTERNAL_URL", "https://platform.brainzlab.ai")
      redirect_to dashboard_projects_path, alert: "Projects are managed in Platform. Visit #{platform_url} to create new projects."
    end
  end
end
