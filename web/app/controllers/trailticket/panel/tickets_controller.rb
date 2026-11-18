# frozen_string_literal: true

class Trailticket::Panel::TicketsController < Trailticket::Panel::ApplicationController
  BOARD_LIMIT = 50
  PER_PAGE = 25

  before_action :set_ticket, only: %i[show status screenshot]

  # GET /  — one column per status.
  def board
    @counts = Trailticket::Ticket.group(:status).count
    @columns = Trailticket.config.statuses.index_with do |status|
      base_scope.where(status: status).order(updated_at: :desc, id: :desc).limit(BOARD_LIMIT).to_a
    end
  end

  # GET /list?q=&status=&priority=&page=
  def index
    @filters = filters
    scope = filtered_scope
    @total = scope.count
    @pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params.fetch(:page, 1).to_i.clamp(1, @pages)
    @tickets = base_scope.merge(scope).order(updated_at: :desc, id: :desc)
                         .offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def show
    render_ticket_page
  end

  # PATCH /tickets/:id/status  status=...  (HTML form or JSON from the board)
  def status
    @ticket.status = params.fetch(:status, '').to_s
    @ticket.closed_by = current_actor if @ticket.status_changed? && @ticket.final_status?

    if @ticket.save
      respond_to do |format|
        format.html { redirect_to ticket_path(@ticket), status: :see_other }
        format.json { render json: { id: @ticket.id, status: @ticket.status } }
      end
    else
      status_failed
    end
  end

  # The screenshot goes through the same authorization as the page.
  def screenshot
    return head(:not_found) unless @ticket.screenshot?

    blob = @ticket.screenshot.blob
    response.headers['Cache-Control'] = 'private, max-age=300'
    send_data blob.download, type: blob.content_type, disposition: 'inline',
                             filename: blob.filename.to_s
  end

  private

  def set_ticket
    @ticket = Trailticket::Ticket.find(params.fetch(:id))
  end

  def base_scope
    Trailticket::Ticket.includes(:author, :subject)
  end

  # Optional and forgiving: unknown values are ignored, not an error.
  def filters
    {
      q: params.fetch(:q, '').to_s.strip.first(200),
      status: params.fetch(:status, nil).presence_in(Trailticket.config.statuses),
      priority: params.fetch(:priority, nil).presence_in(Trailticket::Ticket::PRIORITIES)
    }
  end

  def filtered_scope
    scope = Trailticket::Ticket.all
    if @filters[:q].present?
      pattern = "%#{Trailticket::Ticket.sanitize_sql_like(@filters[:q])}%"
      scope = scope.where(Trailticket::Ticket.arel_table[:title].matches(pattern, '\\'))
    end
    scope = scope.where(status: @filters[:status]) if @filters[:status]
    scope = scope.where(priority: @filters[:priority]) if @filters[:priority]
    scope
  end

  # Own message for the common case, so it does not depend on the app having
  # Active Record translations for its locale.
  def status_error_message
    return @ticket.errors.full_messages.to_sentence unless @ticket.errors.include?(:status)

    I18n.t('trailticket.web.invalid_status', status: @ticket.status)
  end

  def status_failed
    @error = status_error_message
    @ticket.restore_attributes
    respond_to do |format|
      format.html { render_ticket_page(status: :unprocessable_content) }
      format.json { render json: { error: @error }, status: :unprocessable_content }
    end
  end
end
