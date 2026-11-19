# frozen_string_literal: true

class Trailticket::Panel::TicketsController < Trailticket::Panel::ApplicationController
  BOARD_LIMIT = 50
  PER_PAGE = 25

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
    filter = Trailticket::Panel::TicketFilter.new(params)
    @filters = filter.to_h
    paginate(filter.scope)
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

  def paginate(scope)
    @total = scope.count
    @pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params.fetch(:page, 1).to_i.clamp(1, @pages)
    @tickets = base_scope.merge(scope).order(updated_at: :desc, id: :desc)
                         .offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
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
      tickets: board_order(base_scope.merge(visible), final).limit(BOARD_LIMIT).to_a
    )
  end

  # Work columns are a queue (most urgent, then oldest first); final columns show
  # the most recently closed first.
  def board_order(scope, final)
    final ? scope.order(closed_at: :desc, id: :desc) : scope.by_priority.order(:created_at, :id)
  end

  # Own message for the common case, so it does not depend on the app having
  # Active Record translations for its locale.
  def status_error_message
    if @ticket.errors.of_kind?(:priority, :required_for_triage)
      initial = Trailticket::Ticket.initial_status
      label = I18n.t("trailticket.statuses.#{initial}", default: initial.humanize)
      return I18n.t('trailticket.web.triage.required', status: label)
    end
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
