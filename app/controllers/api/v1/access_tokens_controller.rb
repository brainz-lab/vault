module Api
  module V1
    class AccessTokensController < BaseController
      before_action :require_admin!
      before_action :set_token, only: [:show, :update, :destroy, :regenerate]

      # GET /api/v1/access_tokens
      def index
        tokens = current_project.access_tokens.order(created_at: :desc)

        render json: {
          tokens: tokens.map { |t| token_json(t) }
        }
      end

      # GET /api/v1/access_tokens/:id
      def show
        render json: token_json(@token)
      end

      # POST /api/v1/access_tokens
      def create
        @token = current_project.access_tokens.build(token_params)
        raw_token = @token.generate_token

        @token.save!

        log_access(action: "create_access_token", details: { name: @token.name })

        render json: token_json(@token, raw_token: raw_token), status: :created
      end

      # PUT/PATCH /api/v1/access_tokens/:id
      def update
        @token.update!(token_params)

        log_access(action: "update_access_token", details: { name: @token.name })

        render json: token_json(@token)
      end

      # DELETE /api/v1/access_tokens/:id
      def destroy
        @token.revoke!

        log_access(action: "revoke_access_token", details: { name: @token.name })

        head :no_content
      end

      # POST /api/v1/access_tokens/:id/regenerate
      def regenerate
        raw_token = @token.regenerate!

        log_access(action: "regenerate_access_token", details: { name: @token.name })

        render json: token_json(@token, raw_token: raw_token)
      end

      private

      def require_admin!
        require_permission!("admin")
      end

      def set_token
        @token = current_project.access_tokens.find(params[:id])
      end

      def token_params
        params.permit(:name, :description, :expires_at, scopes: [], environment_access: [])
      end

      def token_json(token, raw_token: nil)
        json = {
          id: token.id,
          name: token.name,
          description: token.description,
          token_prefix: token.token_prefix,
          scopes: token.scopes,
          environment_access: token.environment_access,
          last_used_at: token.last_used_at,
          expires_at: token.expires_at,
          revoked: token.revoked?,
          created_at: token.created_at
        }

        # Only include raw token on creation or regeneration
        json[:token] = raw_token if raw_token

        json
      end
    end
  end
end
