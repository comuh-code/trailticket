module Trailticket
  # What the signed-in user can do. Frontends use it to decide what to show.
  class MeController < ApplicationController
    def show
      policy = ticket_policy
      json = {
        user: TicketSerializer.user(ticket_user),
        permissions: { open: policy.opener?, manage: policy.manage? },
        statuses: Ticket::STATUSES,
        priorities: Ticket::PRIORITIES,
        screenshots: Ticket.screenshots?
      }
      json[:assignees] = assignee_options.map { |user| TicketSerializer.user(user) } if policy.manage?
      render json: json
    end
  end
end
