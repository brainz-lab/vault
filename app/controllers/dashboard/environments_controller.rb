module Dashboard
  class EnvironmentsController < BaseController
    before_action :require_project!
    before_action :set_environment, only: [ :show, :edit, :update, :destroy ]

    def index
      @environments = current_project.secret_environments
        .left_joins(:secret_versions)
        .select(
          "secret_environments.*",
          "COUNT(DISTINCT secret_versions.secret_id) AS distinct_secrets_count"
        )
        .group("secret_environments.id")
        .includes(:parent_environment)
        .order(:position)
        .load  # Force evaluation in controller, not view
    end

    def show
      @secrets_count = current_project.secrets.active.count
      @versions_count = @environment.secret_versions.count
    end

    def new
      @environment = current_project.secret_environments.build
    end

    def create
      @environment = current_project.secret_environments.build(environment_params)

      if @environment.save
        redirect_to dashboard_project_environments_path(current_project), notice: "Environment created"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @environment.update(environment_params)
        redirect_to dashboard_project_environments_path(current_project), notice: "Environment updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @environment.secret_versions.exists?
        redirect_to dashboard_project_environments_path(current_project),
                    alert: "Cannot delete environment with secrets"
      else
        @environment.destroy
        redirect_to dashboard_project_environments_path(current_project), notice: "Environment deleted"
      end
    end

    private

    def set_environment
      @environment = current_project.secret_environments.find(params[:id])
    end

    def environment_params
      params.require(:secret_environment).permit(:name, :slug, :parent_environment_id, :position, :locked)
    end
  end
end
