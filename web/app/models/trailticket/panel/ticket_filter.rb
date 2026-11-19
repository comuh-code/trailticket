# frozen_string_literal: true

# Search and filters of the ticket list. Optional and forgiving: unknown values
# are ignored, not an error.
class Trailticket::Panel::TicketFilter
  ARCHIVED = %w[only all].freeze
  PRIORITIES = (Trailticket::Ticket::PRIORITIES + ['none']).freeze

  attr_reader :to_h

  def initialize(params)
    @to_h = {
      q: params.fetch(:q, '').to_s.strip.first(200),
      status: params.fetch(:status, nil).presence_in(Trailticket.config.statuses),
      priority: params.fetch(:priority, nil).presence_in(PRIORITIES),
      archived: params.fetch(:archived, nil).presence_in(ARCHIVED)
    }
  end

  def scope
    scope = archive_scope
    scope = search(scope) if to_h[:q].present?
    scope = scope.where(status: to_h[:status]) if to_h[:status]
    priority = to_h[:priority]
    scope = scope.where(priority: priority == 'none' ? nil : priority) if priority
    scope
  end

  private

  # Plain text, not a LIKE pattern; ILIKE on PostgreSQL, LIKE elsewhere.
  def search(scope)
    pattern = "%#{Trailticket::Ticket.sanitize_sql_like(to_h[:q])}%"
    scope.where(Trailticket::Ticket.arel_table[:title].matches(pattern, '\\'))
  end

  # Archived tickets are left out unless asked for.
  def archive_scope
    case to_h[:archived]
    when 'only' then Trailticket::Ticket.archived
    when 'all' then Trailticket::Ticket.all
    else Trailticket::Ticket.unarchived
    end
  end
end
