module Dashboard
  class AccessTokensController < BaseController
    before_action :require_project!
    before_action :set_token, only: [:show, :edit, :update, :destroy, :regenerate]

    def index
      @tokens = current_project.access_tokens.order(created_at: :desc)
    end

    def show
    end

    def new
      @token = current_project.access_tokens.build
    end

    def create
      @token = current_project.access_tokens.build(token_params)
      @raw_token = @token.generate_token

      if @token.save
        flash[:token] = @raw_token
        redirect_to dashboard_project_access_token_path(current_project, @token),
                    notice: "Access token created. Copy it now - you won't see it again!"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @token.update(token_params)
        redirect_to dashboard_project_access_tokens_path(current_project), notice: "Token updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @token.revoke!
      redirect_to dashboard_project_access_tokens_path(current_project), notice: "Token revoked"
    end

    def regenerate
      @raw_token = @token.regenerate!
      flash[:token] = @raw_token
      redirect_to dashboard_project_access_token_path(current_project, @token),
                  notice: "Token regenerated. Copy it now - you won't see it again!"
    end

    private

    def set_token
      @token = current_project.access_tokens.find(params[:id])
    end

    def token_params
      params.require(:access_token).permit(:name, :description, :expires_at, permissions: [], environments: [])
    end
  end
end
