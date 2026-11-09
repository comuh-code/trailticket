module Trailticket
  class TicketsController < ApplicationController
    FILTERS = (Ticket::STATUSES + %w[active all]).freeze
    MAX_PER_PAGE = 100

    before_action :set_ticket, only: %i[show update close reopen screenshot]
    before_action :require_show!, only: %i[show screenshot]
    before_action :require_manage!, only: %i[update close reopen]

    # GET /tickets?status=active|all|open|...&page=1&per=25
    def index
      filter = params[:status].presence_in(FILTERS) || "active"
      page = [params[:page].to_i, 1].max
      per = (params[:per].presence || 25).to_i.clamp(1, MAX_PER_PAGE)

      scope = TicketPolicy::Scope.new(ticket_user).resolve
      scope = case filter
              when "active" then scope.active
              when "all" then scope
              else scope.where(status: filter)
              end

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

      attrs = params.require(:ticket)
      ticket = Trailticket.open_ticket(
        author: ticket_user,
        title: attrs[:title],
        body: attrs[:body],
        priority: attrs[:priority],
        context: attrs[:context],
        screenshot: attrs[:screenshot],
        user_agent: request.user_agent
      )

      if ticket.persisted?
        render json: serialize(ticket, details: true), status: :created
      else
        render json: { errors: ticket.errors.to_hash }, status: 422
      end
    end

    # PATCH /tickets/:id  { ticket: { status, priority, assignee_id } }
    def update
      attrs = params.require(:ticket).permit(:status, :priority, :assignee_id)
      @ticket.assign_attributes(attrs.slice(:status, :priority))
      if attrs.key?(:assignee_id)
        @ticket.assignee = find_assignee(attrs[:assignee_id])
        return render(json: { errors: { assignee_id: ["is not allowed"] } }, status: 422) if @invalid_assignee
      end
      @ticket.closed_by = ticket_user if @ticket.status_changed? && @ticket.status_closed?

      if @ticket.save
        render json: serialize(@ticket, details: true)
      else
        render json: { errors: @ticket.errors.to_hash }, status: 422
      end
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
      response.headers["Cache-Control"] = "private, max-age=300"
      send_data blob.download, type: blob.content_type, disposition: "inline", filename: blob.filename.to_s
    end

    private

    def set_ticket
      @ticket = Ticket.find(params[:id])
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
end
