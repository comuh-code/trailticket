module Trailticket
  # One entry in a ticket's history: a status, priority or assignee change, or
  # the ticket being archived/unarchived.
  # Replies are Trailticket::Message; the ticket page merges both in one timeline.
  class Event < ApplicationRecord
    ACTIONS = %w[status_changed priority_changed assignee_changed archived unarchived].freeze

    belongs_to :ticket, inverse_of: :events
    # Who did it: Trailticket::Current.actor at the time, nil when unknown.
    belongs_to :actor, polymorphic: true, optional: true

    attribute :data, :json, default: -> { {} }

    validates :action, inclusion: { in: ACTIONS }

    def from = data["from"]
    def to = data["to"]
  end
end
