# frozen_string_literal: true

class Trailticket::Panel::TicketsController < Trailticket::Panel::ApplicationController
  PER_PAGE = 25

  before_action :set_ticket, only: %i[show status screenshot]

  # GET /?q=&priority=&assignee=  — one column per status, with the list's filters
  # except status (each column is one) and archived (the board never shows them).
  def board
    filter = ticket_filter(params.except(:status, :archived))
    @filters = filter.to_h
    @columns = Trailticket::Panel::Board.new(filter.scope).columns
  end

  # GET /list?q=&status=&priority=&assignee=&archived=&page=
  def index
    filter = ticket_filter(params)
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

  def ticket_filter(source)
    keys = assignee_options.map { |person| assignee_key(person) }
    Trailticket::Panel::TicketFilter.new(source, actor: current_actor, assignee_keys: keys)
  end

  def base_scope
    Trailticket::Ticket.includes(:author, :subject, :assignee)
  end

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
