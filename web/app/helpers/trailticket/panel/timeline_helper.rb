# frozen_string_literal: true

# The ticket history: opening, recorded events and messages in one list.
module Trailticket::Panel::TimelineHelper
  TimelineEntry = Struct.new(:kind, :at, :record, keyword_init: true)

  # Opening, history events and messages, oldest first.
  def ticket_timeline(ticket, events, messages)
    entries = [TimelineEntry.new(kind: :created, at: ticket.created_at, record: ticket)]
    entries += events.map { |event| entry(:event, event) }
    entries += messages.map { |message| entry(:message, message) }
    entries.sort_by.with_index { |entry, index| [entry.at || Time.current, index] }
  end

  # One sentence per event. The *_html translations escape every interpolated value.
  def event_sentence(event)
    actor = event.actor ? author_label(event.actor) : tt('timeline.someone')
    key, from, to = event_parts(event)
    tt("timeline.#{key}_html", actor: actor, from: from, to: to)
  end

  private

  def entry(kind, record)
    TimelineEntry.new(kind: kind, at: record.created_at, record: record)
  end

  def event_parts(event)
    case event.action
    when 'status_changed' then status_event_parts(event)
    when 'archived', 'unarchived' then [event.action, nil, nil]
    when 'priority_changed'
      ['priority_changed', priority_label(event.from), priority_label(event.to)]
    else
      ['assignee_changed', referenced_label(event.from), referenced_label(event.to)]
    end
  end

  def status_event_parts(event)
    finals = Trailticket::Ticket.final_statuses
    key = if finals.include?(event.to) && finals.exclude?(event.from) then 'closed'
          elsif finals.include?(event.from) && finals.exclude?(event.to) then 'reopened'
          else 'status_changed'
          end
    [key, status_label(event.from), status_label(event.to)]
  end

  # Assignee stored as { "type", "id" }; the record may be gone since.
  def referenced_label(ref)
    unless ref.is_a?(Hash) && ref['type'].present?
      return Trailticket::Panel::ApplicationHelper::EMPTY
    end

    klass = ref['type'].safe_constantize
    record = klass.find_by(id: ref['id']) if klass.is_a?(Class) && klass < ActiveRecord::Base
    record ? author_label(record) : "#{ref['type']} ##{ref['id']}"
  end
end
