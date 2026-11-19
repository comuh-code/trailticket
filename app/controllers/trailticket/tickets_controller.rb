# frozen_string_literal: true

class Trailticket::TicketsController < Trailticket::ApplicationController
  MAX_PER_PAGE = 100

  before_action :set_ticket, only: %i[show update close reopen screenshot]
  before_action :require_show!, only: %i[show screenshot]
  before_action :require_manage!, only: %i[update close reopen]

  # GET /tickets?status=active|all|open|...&page=1&per=25
  def index
    filter = status_filter
    page, per = pagination
    scope = visible_tickets(filter)
    tickets = scope.includes(:author, :assignee, :closed_by)
                   .order(updated_at: :desc)
                   .offset((page - 1) * per).limit(per)

    render json: {
      tickets: tickets.map { |ticket| serialize(ticket) },
      meta: { page: page, per: per, total: scope.count, status: filter }
    }
  end

  def show
    render json: serialize(@ticket, details: true)
  end

  # POST /tickets  { ticket: { title, body, priority, context, screenshot } }
  # screenshot: data URL string or multipart file. context: object or JSON string.
  def create
    return trailticket_deny! unless ticket_policy.create?

    ticket = Trailticket.open_ticket(**new_ticket_attributes)
    respond_with_ticket(ticket.persisted?, ticket, status: :created)
  end

  # PATCH /tickets/:id  { ticket: { status, priority, assignee_id } }
  def update
    attrs = params.require(:ticket).permit(:status, :priority, :assignee_id)
    @ticket.assign_attributes(attrs.slice(:status, :priority))
    if attrs.key?(:assignee_id)
      @ticket.assignee = find_assignee(attrs[:assignee_id])
      return render_errors(assignee_id: ['is not allowed']) if @invalid_assignee
    end
    @ticket.closed_by = ticket_user if @ticket.closing?

    respond_with_ticket(@ticket.save, @ticket)
  end

  def close
    @ticket.close!(by: ticket_user)
    render json: serialize(@ticket, details: true)
  end

  def reopen
    @ticket.reopen!
    render json: serialize(@ticket, details: true)
  end

  # Served through the engine so the same permissions apply to the image.
  def screenshot
    return head(:not_found) unless @ticket.screenshot?

    blob = @ticket.screenshot.blob
    response.headers['Cache-Control'] = 'private, max-age=300'
    send_data blob.download, type: blob.content_type, disposition: 'inline',
                             filename: blob.filename.to_s
  end

  private

  def pagination
    [[params[:page].to_i, 1].max, (params[:per].presence || 25).to_i.clamp(1, MAX_PER_PAGE)]
  end

  def visible_tickets(filter)
    scope = Trailticket::TicketPolicy::Scope.new(ticket_user).resolve
    case filter
    when 'active' then scope.active
    when 'all' then scope
    else scope.where(status: filter)
    end
  end

  # POST /tickets  { ticket: { title, body, priority, context, screenshot } }
  def new_ticket_attributes
    attrs = params.require(:ticket)
    fields = %i[title body priority context screenshot].index_with { |key| attrs[key] }
    fields.merge(author: ticket_user, user_agent: request.user_agent)
  end

  def respond_with_ticket(saved, ticket, status: :ok)
    return render(json: serialize(ticket, details: true), status: status) if saved

    render_errors(ticket.errors.to_hash)
  end

  def render_errors(errors)
    render json: { errors: errors }, status: :unprocessable_content
  end

  def set_ticket
    @ticket = Trailticket::Ticket.find(params[:id])
  end

  def status_filter
    params[:status].presence_in(Trailticket.config.statuses + %w[active all]) || 'active'
  end

  def require_show!
    trailticket_deny! unless ticket_policy(@ticket).show?
  end

  def require_manage!
    trailticket_deny! unless ticket_policy(@ticket).manage?
  end

  def find_assignee(id)
    return nil if id.blank?

    assignee_options.find { |user| user.id.to_s == id.to_s }.tap do |user|
      @invalid_assignee = user.nil?
    end
  end
end
