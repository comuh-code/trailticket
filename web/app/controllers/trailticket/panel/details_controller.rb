# frozen_string_literal: true

class Trailticket::Panel::DetailsController < Trailticket::Panel::ApplicationController
  before_action { @ticket = Trailticket::Ticket.find(params.fetch(:id)) }

  def update
    priority = params.fetch(:priority, '').to_s
    @ticket.priority = priority if priority.present?
    if params.key?(:assignee)
      assignee = find_assignee(params.fetch(:assignee).to_s)
      return details_failed(I18n.t('trailticket.web.details.invalid_assignee')) if assignee == false

      @ticket.assignee = assignee
    end

    save_details
  end

  private

  def find_assignee(key)
    return nil if key.empty?
    return @ticket.assignee if key == assignee_key(@ticket.assignee)

    assignee_options.find { |option| assignee_key(option) == key } || false
  end

  def save_details
    if @ticket.save
      redirect_to ticket_path(@ticket), status: :see_other
    else
      details_failed(@ticket.errors.full_messages.to_sentence)
    end
  end

  def details_failed(message)
    @error = message
    @ticket.restore_attributes
    render_ticket_page(status: :unprocessable_content)
  end
end
