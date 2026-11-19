# frozen_string_literal: true

class Trailticket::Panel::MessagesController < Trailticket::Panel::ApplicationController
  def create
    @ticket = Trailticket::Ticket.find(params.fetch(:ticket_id))
    @reply = build_reply

    if @reply.author && @reply.save
      redirect_to ticket_path(@ticket, anchor: "message-#{@reply.id}"), status: :see_other
    else
      @reply_error = reply_error
      render_ticket_page(status: :unprocessable_content)
    end
  end

  private

  def build_reply
    @ticket.messages.new(
      body: params.fetch(:body, '').to_s,
      internal: ActiveModel::Type::Boolean.new.cast(params.fetch(:internal, false)) == true,
      author: current_actor
    )
  end

  def reply_error
    return I18n.t('trailticket.web.reply.no_actor') unless @reply.author
    return I18n.t('trailticket.web.reply.blank') if @reply.errors.include?(:body)

    @reply.errors.full_messages.to_sentence
  end
end
