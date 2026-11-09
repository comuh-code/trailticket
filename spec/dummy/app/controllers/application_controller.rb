class ApplicationController < ActionController::Base
  # In tests the "session" comes from a header.
  def current_admin
    @current_admin ||= Admin.find_by(id: request.headers["X-Admin-Id"])
  end
end
