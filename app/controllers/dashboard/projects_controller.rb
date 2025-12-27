module Dashboard
  class ProjectsController < BaseController
    skip_before_action :set_current_project, only: [:index, :new, :create]
    before_action :set_project, only: [:show, :edit, :update, :destroy, :setup, :mcp_setup]

    def index
      # In development, show all projects
      @projects = if Rails.env.development?
        Project.all.order(:name)
      else
        Project.where(organization_id: current_user[:organization_id])
               .or(Project.where(organization_id: nil))
               .order(:name)
      end
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
        create_default_environments(@project)
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
          scopes: ["read", "write"],
          description: "Token for MCP integration"
        )
        @raw_token = @token.generate_token
        @token.save!
      end
    end

    private

    def set_project
      @project = Project.find(params[:id])
    end

    def project_params
      params.require(:project).permit(:name, :platform_project_id)
    end

    def create_default_environments(project)
      [
        { name: "Production", slug: "production", position: 0, locked: true },
        { name: "Staging", slug: "staging", position: 1, inherits_from: "production" },
        { name: "Development", slug: "development", position: 2, inherits_from: "staging" }
      ].each do |env|
        project.secret_environments.create!(env)
      end
    end
  end
end
