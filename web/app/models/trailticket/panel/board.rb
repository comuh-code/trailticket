# frozen_string_literal: true

class Trailticket::Panel::Board
  LIMIT = 50

  Column = Struct.new(:status, :tickets, :shown, :total, :window, keyword_init: true)

  def initialize(scope)
    @scope = scope
  end

  def columns
    Trailticket.config.statuses.map { |status| column(status) }
  end

  private

  def column(status)
    scope = @scope.where(status: status)
    final = Trailticket::Ticket.final_statuses.include?(status)
    days = Trailticket.config.board_closed_days if final
    visible = days ? scope.where(closed_at: days.days.ago..) : scope
    cards = order(visible.includes(:author, :subject, :assignee), final).limit(LIMIT)
    Column.new(status: status, window: days, shown: visible.count, total: scope.count,
               tickets: cards.to_a)
  end

  def order(scope, final)
    final ? scope.order(closed_at: :desc, id: :desc) : scope.by_priority.order(:created_at, :id)
  end
end
