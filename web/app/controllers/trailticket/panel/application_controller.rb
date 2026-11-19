# frozen_string_literal: true

class Trailticket::Panel::ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  layout 'trailticket/panel/application'

  before_action :authorize_trailticket_web!
  before_action { Trailticket::Current.actor = current_actor }

  rescue_from ActiveRecord::RecordNotFound do
    render_error :not_found, 'not_found'
  end

  helper_method :assignee_options, :assignee_key, :current_actor, :web_asset_version

  def web_asset_version(file)
    path = Trailticket::Web.root.join('assets', File.basename(file.to_s))
    return Trailticket::VERSION unless path.file?

    "#{Trailticket::VERSION}-#{Digest::SHA256.file(path).hexdigest.first(8)}"
  end

  private

  def assignee_options
    @assignee_options ||= Trailticket.config.assignees&.call&.to_a || [current_actor].compact
  end

  def assignee_key(record)
    "#{record.class.name}:#{record.id}" if record
  end

  def current_actor
    Trailticket.config.current_actor&.call(request)
  end

  def authorize_trailticket_web!
    return if Trailticket.config.authorize&.call(request)

    render_error :forbidden, 'forbidden'
  end

  def render_ticket_page(status: :ok)
    @messages = @ticket.messages.includes(:author).to_a
    @events = @ticket.events.includes(:actor).to_a
    render 'trailticket/panel/tickets/show', status: status, formats: :html
  end

  def render_error(status, page)
    if request.format.json?
      render json: { error: I18n.t("trailticket.web.#{page}.title") }, status: status
    else
      render "trailticket/panel/shared/#{page}", status: status, formats: :html
    end
  end
end
