module Dashboard
  class ProjectsController < BaseController
    # Skip set_current_project for actions that load their own project via set_project
    # This prevents duplicate Project.find queries (N+1 optimization)
    skip_before_action :set_current_project, only: [:index, :new, :create, :show, :edit, :update, :destroy, :setup, :mcp_setup]
    before_action :set_project, only: [:show, :edit, :update, :destroy, :setup, :mcp_setup]

    def index
      # In development, show all projects
      # Use scalar subqueries to load all counts in a single query (avoids N+1)
      base_scope = if Rails.env.development?
        Project.all
      else
        Project.where(organization_id: current_user[:organization_id])
               .or(Project.where(organization_id: nil))
      end

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
      # Only set organization_id in production
      @project.organization_id = current_user[:organization_id] if @project.respond_to?(:organization_id=)

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
          permissions: ["read", "write"]  # Fixed: was 'scopes', removed non-existent 'description'
        )
        @token.save!
        @raw_token = @token.plain_token  # Access the token set by before_validation callback
      end
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
  end
end
