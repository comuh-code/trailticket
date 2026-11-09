module Trailticket
  class ApplicationController < Trailticket.config.parent_controller.constantize
    before_action :trailticket_authenticate!

    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "not_found" }, status: :not_found
    end

    private

    def ticket_user
      return @ticket_user if defined?(@ticket_user)

      @ticket_user = send(Trailticket.config.current_user_method)
    end

    def ticket_policy(ticket = nil)
      TicketPolicy.new(ticket_user, ticket)
    end

    def assignee_options
      @assignee_options ||= Trailticket.config.assignees&.call&.to_a || [ticket_user].compact
    end

    def serialize(ticket, details: false)
      TicketSerializer.new(
        ticket,
        policy: ticket_policy(ticket),
        screenshot_url: screenshot_ticket_path(ticket),
        details: details
      )
    end

    def trailticket_authenticate!
      if (auth = Trailticket.config.authenticate)
        instance_exec(&auth)
        return if performed?
      end

      trailticket_deny! unless ticket_policy.access?
    end

    def trailticket_deny!
      if (handler = Trailticket.config.access_denied)
        instance_exec(&handler)
      else
        render json: { error: "forbidden" }, status: :forbidden
      end
    end
  end
end
