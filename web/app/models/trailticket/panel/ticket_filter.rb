# frozen_string_literal: true

# Search and filters of the ticket list. Optional and forgiving: unknown values
# are ignored, not an error.
class Trailticket::Panel::TicketFilter
  ARCHIVED = %w[only all].freeze
  PRIORITIES = (Trailticket::Ticket::PRIORITIES + ['none']).freeze

  ASSIGNEES = %w[me none].freeze

  attr_reader :to_h

  # actor: who is looking ("me"); assignee_keys: "Class:id" of the people the
  # assignee filter offers.
  def initialize(params, actor: nil, assignee_keys: [])
    @actor = actor
    @to_h = {
      q: params.fetch(:q, '').to_s.strip.first(200),
      status: params.fetch(:status, nil).presence_in(Trailticket.config.statuses),
      priority: params.fetch(:priority, nil).presence_in(PRIORITIES),
      assignee: params.fetch(:assignee, nil).presence_in(ASSIGNEES + assignee_keys),
      archived: params.fetch(:archived, nil).presence_in(ARCHIVED)
    }
  end

  def scope
    scope = archive_scope
    scope = search(scope) if to_h[:q].present?
    scope = scope.where(status: to_h[:status]) if to_h[:status]
    priority = to_h[:priority]
    scope = scope.where(priority: priority == 'none' ? nil : priority) if priority
    to_h[:assignee] ? assignee_scope(scope) : scope
  end

  private

  # Plain text, not a LIKE pattern; ILIKE on PostgreSQL, LIKE elsewhere.
  def search(scope)
    pattern = "%#{Trailticket::Ticket.sanitize_sql_like(to_h[:q])}%"
    scope.where(Trailticket::Ticket.arel_table[:title].matches(pattern, '\\'))
  end

  def assignee_scope(scope)
    case to_h[:assignee]
    when 'none' then scope.where(assignee_id: nil)
    when 'me' then @actor ? scope.where(assignee: @actor) : scope.none
    else
      type, _, id = to_h[:assignee].rpartition(':')
      scope.where(assignee_type: type, assignee_id: id)
    end
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
