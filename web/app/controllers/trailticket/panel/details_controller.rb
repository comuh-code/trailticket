# frozen_string_literal: true

# Priority and assignee, set from the ticket page (the triage step).
class Trailticket::Panel::DetailsController < Trailticket::Panel::ApplicationController
  before_action { @ticket = Trailticket::Ticket.find(params.fetch(:id)) }

  # PATCH /tickets/:id/details  priority=high&assignee=Admin:3
  def update
    priority = params.fetch(:priority, '').to_s
    # The priority can be set or changed here, never cleared.
    @ticket.priority = priority if priority.present?
    if params.key?(:assignee)
      assignee = find_assignee(params.fetch(:assignee).to_s)
      return details_failed(I18n.t('trailticket.web.details.invalid_assignee')) if assignee == false

      @ticket.assignee = assignee
    end

    save_details
  end

  private

  # nil for "Nobody"; false when the key is not one of the options. Keeping the
  # current assignee is fine even if it is no longer an option.
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
