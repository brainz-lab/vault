module Dashboard
  class BaseController < ActionController::Base
    include ActionController::Cookies

    before_action :require_session!, unless: -> { skip_authentication? }
    before_action :set_current_project
    helper_method :current_user, :current_project, :standalone_mode?

    layout "dashboard"

    private

    def standalone_mode?
      ENV["VAULT_STANDALONE_MODE"].present?
    end

    def skip_authentication?
      Rails.env.development? || standalone_mode?
    end

    def require_session!
      unless session[:user_id].present? && session[:expires_at].to_i > Time.current.to_i
        redirect_to sso_login_url, allow_other_host: true
      end
    end

    def current_user
      @current_user ||= if standalone_mode? && session[:user_id].blank?
        {
          id: "standalone_user",
          email: "admin@localhost",
          name: "Standalone Admin",
          organization_id: "standalone_org"
        }
      else
        {
          id: session[:user_id],
          email: session[:email],
          name: session[:name],
          organization_id: session[:organization_id]
        }
      end
    end

    def set_current_project
      return unless defined?(Project)
      # Skip if already loaded (prevents duplicate queries)
      return if @current_project.present?

      # Eager load secret_environments to avoid N+1 queries in layout navigation
      # The layout sidebar uses @current_project.secret_environments for various links
      if params[:project_id]
        @current_project = Project.includes(:secret_environments).find(params[:project_id])
      elsif session[:current_project_id]
        @current_project = Project.includes(:secret_environments).find_by(id: session[:current_project_id])
      end

      # In development or standalone mode, auto-create a project if none exists
      if (Rails.env.development? || standalone_mode?) && @current_project.nil?
        @current_project = Project.includes(:secret_environments).first
        unless @current_project
          @current_project = Project.create!(
            platform_project_id: "dev_#{SecureRandom.hex(4)}",
            name: "Development Project"
          )
          @current_project = Project.includes(:secret_environments).find(@current_project.id)
        end
        session[:current_project_id] = @current_project.id
      end
    end

    def current_project
      @current_project
    end

    def require_project!
      unless current_project
        redirect_to dashboard_projects_path, alert: "Please select a project"
      end
    end

    def sso_login_url
      platform_url = ENV["BRAINZLAB_PLATFORM_URL"] || "http://platform.localhost:2999"
      return_url = CGI.escape(request.original_url)
      "#{platform_url}/login?return_to=#{return_url}&app=vault"
    end
  end
end
