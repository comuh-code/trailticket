# frozen_string_literal: true

# What the signed-in user can do. Frontends use it to decide what to show.
class Trailticket::MeController < Trailticket::ApplicationController
  def show
    policy = ticket_policy
    json = {
      user: user_json(ticket_user),
      permissions: { open: policy.opener?, manage: policy.manage? },
      statuses: Trailticket.config.statuses,
      priorities: Trailticket::Ticket::PRIORITIES,
      screenshots: Trailticket::Ticket.screenshots?
    }
    json[:assignees] = assignee_options.map { |user| user_json(user) } if policy.manage?
    render json: json
  end

  private

  def user_json(user) = Trailticket::TicketSerializer.user(user)
end
