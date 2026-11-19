# frozen_string_literal: true

class Trailticket::Event < Trailticket::ApplicationRecord
  ACTIONS = %w[status_changed priority_changed assignee_changed archived unarchived].freeze

  belongs_to :ticket, inverse_of: :events
  belongs_to :actor, polymorphic: true, optional: true

  attribute :data, :json, default: -> { {} }

  validates :action, inclusion: { in: ACTIONS }

  def from = data['from']
  def to = data['to']
end
