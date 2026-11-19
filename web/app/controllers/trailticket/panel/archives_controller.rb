# frozen_string_literal: true

# Archiving takes a done ticket off the board and the default list.
class Trailticket::Panel::ArchivesController < Trailticket::Panel::ApplicationController
  before_action { @ticket = Trailticket::Ticket.find(params.fetch(:id)) }

  # POST /tickets/:id/archive — only tickets in a final status.
  def create
    unless @ticket.archivable?
      @error = I18n.t('trailticket.web.archive.not_final')
      return render_ticket_page(status: :unprocessable_content)
    end

    @ticket.archive!
    redirect_back_or_to ticket_path(@ticket), status: :see_other
  end

  # DELETE /tickets/:id/archive
  def destroy
    @ticket.unarchive! if @ticket.archived?
    redirect_back_or_to ticket_path(@ticket), status: :see_other
  end
end
