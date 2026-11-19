# frozen_string_literal: true

class Trailticket::Panel::TicketsController < Trailticket::Panel::ApplicationController
  BOARD_LIMIT = 50
  PER_PAGE = 25
  ARCHIVE_FILTERS = %w[only all].freeze

  # tickets: cards shown; shown: tickets in the column (within the closed window);
  # total: every unarchived ticket with that status, for the "see all" link.
  BoardColumn = Struct.new(:status, :tickets, :shown, :total, :window, keyword_init: true)

  before_action :set_ticket, only: %i[show status screenshot]

  # GET /  — one column per status. Archived tickets never show; final columns
  # only show tickets closed in the last config.board_closed_days days.
  def board
    @columns = Trailticket.config.statuses.map { |status| board_column(status) }
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
    @ticket.closed_by = current_actor if @ticket.closing?

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

  def board_column(status)
    scope = Trailticket::Ticket.unarchived.where(status: status)
    final = Trailticket::Ticket.final_statuses.include?(status)
    days = Trailticket.config.board_closed_days if final
    visible = days ? scope.where(closed_at: days.days.ago..) : scope
    BoardColumn.new(
      status: status, window: days, shown: visible.count, total: scope.count,
      tickets: base_scope.merge(visible).order(updated_at: :desc, id: :desc).limit(BOARD_LIMIT).to_a
    )
  end

  # Optional and forgiving: unknown values are ignored, not an error.
  def filters
    {
      q: params.fetch(:q, '').to_s.strip.first(200),
      status: params.fetch(:status, nil).presence_in(Trailticket.config.statuses),
      priority: params.fetch(:priority, nil).presence_in(Trailticket::Ticket::PRIORITIES),
      archived: params.fetch(:archived, nil).presence_in(ARCHIVE_FILTERS)
    }
  end

  def filtered_scope
    scope = archive_scope
    if @filters[:q].present?
      pattern = "%#{Trailticket::Ticket.sanitize_sql_like(@filters[:q])}%"
      scope = scope.where(Trailticket::Ticket.arel_table[:title].matches(pattern, '\\'))
    end
    scope = scope.where(status: @filters[:status]) if @filters[:status]
    scope = scope.where(priority: @filters[:priority]) if @filters[:priority]
    scope
  end

  # Archived tickets are left out of the list unless asked for.
  def archive_scope
    case @filters[:archived]
    when 'only' then Trailticket::Ticket.archived
    when 'all' then Trailticket::Ticket.all
    else Trailticket::Ticket.unarchived
    end
  end

  # Own message for the common case, so it does not depend on the app having
  # Active Record translations for its locale.
  def status_error_message
    return @ticket.errors.full_messages.to_sentence unless @ticket.errors.include?(:status)

    I18n.t('trailticket.web.invalid_status', status: @ticket.status)
  end

  def status_failed
    message = status_error_message
    @ticket.restore_attributes
    respond_to do |format|
      format.html do
        @error = I18n.t('trailticket.web.status_error', error: message)
        render_ticket_page(status: :unprocessable_content)
      end
      format.json { render json: { error: message }, status: :unprocessable_content }
    end
  end
end
