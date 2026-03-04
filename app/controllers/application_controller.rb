class ApplicationController < ActionController::API
  include ActionController::Cookies

  rescue_from StandardError do |exception|
    BrainzLab::Reflex.capture(exception, context: { controller: self.class.name, action: action_name })
    BrainzLab::Signal.trigger("app.unhandled_error", severity: :critical, details: { error: exception.message })
    raise exception
  end

  private

  def current_project
    @current_project
  end
end
