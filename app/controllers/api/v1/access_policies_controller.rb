module Api
  module V1
    class AccessPoliciesController < BaseController
      before_action :require_admin!
      before_action :set_policy, only: [:show, :update, :destroy]

      # GET /api/v1/access_policies
      def index
        policies = current_project.access_policies.includes(:access_token).order(:name)

        render json: {
          policies: policies.map { |p| policy_json(p) }
        }
      end

      # GET /api/v1/access_policies/:id
      def show
        render json: policy_json(@policy)
      end

      # POST /api/v1/access_policies
      def create
        @policy = current_project.access_policies.build(policy_params)
        @policy.save!

        log_access(action: "create_policy", details: { name: @policy.name })

        render json: policy_json(@policy), status: :created
      end

      # PUT/PATCH /api/v1/access_policies/:id
      def update
        @policy.update!(policy_params)

        log_access(action: "update_policy", details: { name: @policy.name })

        render json: policy_json(@policy)
      end

      # DELETE /api/v1/access_policies/:id
      def destroy
        @policy.destroy!

        log_access(action: "delete_policy", details: { name: @policy.name })

        head :no_content
      end

      private

      def require_admin!
        require_permission!("admin")
      end

      def set_policy
        @policy = current_project.access_policies.find(params[:id])
      end

      def policy_params
        params.permit(
          :name,
          :principal_type,
          :principal_id,
          :enabled,
          permissions: [],
          environments: [],
          paths: [],
          conditions: {}
        )
      end

      def policy_json(policy)
        {
          id: policy.id,
          name: policy.name,
          principal_type: policy.principal_type,
          principal_id: policy.principal_id,
          permissions: policy.permissions,
          environments: policy.environments,
          paths: policy.paths,
          conditions: policy.conditions,
          enabled: policy.enabled,
          token_name: policy.access_token&.name,
          created_at: policy.created_at
        }
      end
    end
  end
end
