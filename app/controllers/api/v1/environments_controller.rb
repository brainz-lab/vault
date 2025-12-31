module Api
  module V1
    class EnvironmentsController < BaseController
      before_action :set_environment, only: [ :show, :update, :destroy ]

      # GET /api/v1/environments
      def index
        environments = current_project.secret_environments.order(:position)

        render json: {
          environments: environments.map { |e| environment_json(e) }
        }
      end

      # GET /api/v1/environments/:slug
      def show
        render json: environment_json(@environment)
      end

      # POST /api/v1/environments
      def create
        require_permission!("admin")

        @environment = current_project.secret_environments.build(environment_params)
        @environment.save!

        log_access(action: "create_environment", details: { slug: @environment.slug })

        render json: environment_json(@environment), status: :created
      end

      # PUT/PATCH /api/v1/environments/:slug
      def update
        require_permission!("admin")

        @environment.update!(environment_params)

        log_access(action: "update_environment", details: { slug: @environment.slug })

        render json: environment_json(@environment)
      end

      # DELETE /api/v1/environments/:slug
      def destroy
        require_permission!("admin")

        if @environment.secret_versions.exists?
          render json: { error: "Cannot delete environment with secrets" }, status: :unprocessable_entity
          return
        end

        @environment.destroy!

        log_access(action: "delete_environment", details: { slug: @environment.slug })

        head :no_content
      end

      private

      def set_environment
        @environment = current_project.secret_environments.find_by!(slug: params[:slug])
      end

      def environment_params
        params.permit(:name, :slug, :parent_environment_id, :position, :locked, :protected, :color)
      end

      def environment_json(env)
        {
          id: env.id,
          name: env.name,
          slug: env.slug,
          parent_environment_id: env.parent_environment_id,
          protected: env.protected,
          locked: env.locked,
          color: env.color,
          position: env.position,
          secrets_count: env.secret_versions.select(:secret_id).distinct.count,
          created_at: env.created_at
        }
      end
    end
  end
end
