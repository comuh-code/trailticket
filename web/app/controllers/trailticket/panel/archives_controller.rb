# frozen_string_literal: true

class Trailticket::Panel::ArchivesController < Trailticket::Panel::ApplicationController
  before_action { @ticket = Trailticket::Ticket.find(params.fetch(:id)) }

  def create
    unless @ticket.archivable?
      @error = I18n.t('trailticket.web.archive.not_final')
      return render_ticket_page(status: :unprocessable_content)
    end

    @ticket.archive!
    redirect_back_or_to ticket_path(@ticket), status: :see_other
  end

  def destroy
    @ticket.unarchive! if @ticket.archived?
    redirect_back_or_to ticket_path(@ticket), status: :see_other
  end
end
