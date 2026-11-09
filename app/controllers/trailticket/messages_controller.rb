module Trailticket
  class MessagesController < ApplicationController
    # POST /tickets/:ticket_id/messages  { message: { body, internal } }
    def create
      ticket = Ticket.find(params[:ticket_id])
      policy = ticket_policy(ticket)
      return trailticket_deny! unless policy.reply?

      message = ticket.messages.new(
        body: params.dig(:message, :body),
        author: ticket_user,
        internal: policy.manage? && ActiveModel::Type::Boolean.new.cast(params.dig(:message, :internal)) == true
      )

      if message.save
        render json: TicketSerializer.message(message), status: :created
      else
        render json: { errors: message.errors.to_hash }, status: 422
      end
    end
  end
end
