# frozen_string_literal: true

class Trailticket::MessagesController < Trailticket::ApplicationController
  # POST /tickets/:ticket_id/messages  { message: { body, internal } }
  def create
    ticket = Trailticket::Ticket.find(params[:ticket_id])
    policy = ticket_policy(ticket)
    return trailticket_deny! unless policy.reply?

    message = ticket.messages.new(body: params.dig(:message, :body), author: ticket_user,
                                  internal: policy.manage? && internal_param?)

    if message.save
      render json: Trailticket::TicketSerializer.message(message), status: :created
    else
      render json: { errors: message.errors.to_hash }, status: :unprocessable_content
    end
  end

  private

  # Only managers can write internal notes; anyone else's flag is ignored.
  def internal_param?
    ActiveModel::Type::Boolean.new.cast(params.dig(:message, :internal)) == true
  end
end
