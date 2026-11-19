# frozen_string_literal: true

class ApplicationController < ActionController::Base
  def current_admin
    return @current_admin if defined?(@current_admin)

    @current_admin = Admin.find_by(id: request.headers['X-Admin-Id'])
  end
end
