class ApplicationController < ActionController::API
  include ActionController::Cookies

  private

  def current_project
    @current_project
  end
end
