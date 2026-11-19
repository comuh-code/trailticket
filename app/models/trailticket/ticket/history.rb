# frozen_string_literal: true

module Trailticket::Ticket::History
  extend ActiveSupport::Concern

  included do
    has_many :events, -> { order(:created_at, :id) },
             dependent: :delete_all, inverse_of: :ticket

    after_update :record_history
  end

  private

  def record_history
    record_event('status_changed', *saved_change_to_status) if saved_change_to_status?
    record_event('priority_changed', *saved_change_to_priority) if saved_change_to_priority?
    record_archive_event if saved_change_to_archived_at?
    record_assignee_event if saved_change_to_assignee_id? || saved_change_to_assignee_type?
  end

  def record_event(action, from, to)
    events.create!(action: action, actor: Trailticket::Current.actor,
                   data: { 'from' => from, 'to' => to })
  end

  def record_assignee_event
    before = record_ref(assignee_type_before_last_save, assignee_id_before_last_save)
    record_event('assignee_changed', before, record_ref(assignee_type, assignee_id))
  end

  def record_archive_event
    from, to = saved_change_to_archived_at
    return if to.nil? && saved_change_to_status?

    record_event(to ? 'archived' : 'unarchived', from&.iso8601, to&.iso8601)
  end

  def record_ref(type, id)
    { 'type' => type, 'id' => id } if type && id
  end
end
