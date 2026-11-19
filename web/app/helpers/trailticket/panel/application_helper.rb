# frozen_string_literal: true

# Everything here returns plain strings or tags built with content_tag, so user
# data is always escaped. Nothing calls html_safe or raw.
module Trailticket::Panel::ApplicationHelper
  SAFE_SCHEMES = %w[http https].freeze
  MAX_DEPTH = 8
  EMPTY = '—'

  def tt(key, **options)
    t("trailticket.web.#{key}", **options)
  end

  def status_label(status)
    t("trailticket.statuses.#{status}", default: status.to_s.humanize)
  end

  def priority_label(priority)
    return tt('triage.no_priority') if priority.blank?

    t("trailticket.priorities.#{priority}", default: priority.to_s.humanize)
  end

  def author_label(record)
    record ? Trailticket.config.author_label.call(record).to_s : EMPTY
  end

  def subject_label(record)
    record ? Trailticket.config.subject_label.call(record).to_s : EMPTY
  end

  def status_badge(status)
    css = "tt-badge tt-status tt-status-#{status.to_s.parameterize}"
    content_tag(:span, status_label(status), class: css)
  end

  def priority_badge(priority)
    content_tag(:span, priority_label(priority),
                class: "tt-badge tt-priority-#{priority.presence || 'none'}")
  end

  # "No priority (suggested: High)" while in triage.
  def triage_badge(ticket)
    return priority_badge(ticket.priority) unless ticket.priority.nil?

    text = priority_label(nil)
    if (suggested = ticket.suggested_priority)
      text = tt('triage.suggested_short', text: text, priority: priority_label(suggested))
    end
    content_tag(:span, text, class: 'tt-badge tt-priority-none', data: { tt_needs_priority: true })
  end

  def time_label(time)
    return EMPTY unless time

    time_tag(time, time.strftime('%Y-%m-%d %H:%M'))
  end

  # Only http(s) URLs become links. javascript:, data: and anything else is text.
  def safe_link(url, text = url)
    return EMPTY if url.blank?
    return text.to_s unless safe_url?(url)

    link_to text.to_s, url.to_s, target: '_blank', rel: 'noopener noreferrer nofollow'
  end

  def safe_url?(url)
    SAFE_SCHEMES.include?(URI.parse(url.to_s.strip).scheme&.downcase)
  rescue URI::Error
    false
  end

  def ticket_trail(ticket)
    trail = ticket.context.is_a?(Hash) ? ticket.context['trail'] : nil
    Array(trail).grep(Hash)
  end

  # Everything in the context except the trail, which has its own section.
  def ticket_context(ticket)
    ticket.context.is_a?(Hash) ? ticket.context.except('trail') : {}
  end

  # Renders any JSON value as nested key → value lists.
  def context_value(value, depth = 0)
    return muted('…') if depth > MAX_DEPTH

    case value
    when Hash then context_hash(value, depth)
    when Array then context_array(value, depth)
    when nil then muted('null')
    else
      string = value.to_s
      string.match?(%r{\Ahttps?://}i) ? safe_link(string) : string
    end
  end

  private

  def context_hash(hash, depth)
    return muted('{}') if hash.empty?

    content_tag(:dl, class: 'tt-kv') do
      safe_join(hash.map do |key, val|
        content_tag(:dt, key.to_s) + content_tag(:dd, context_value(val, depth + 1))
      end)
    end
  end

  def context_array(array, depth)
    return muted('[]') if array.empty?

    content_tag(:ol, class: 'tt-tree-list') do
      safe_join(array.map { |val| content_tag(:li, context_value(val, depth + 1)) })
    end
  end

  def muted(text)
    content_tag(:span, text, class: 'tt-muted')
  end
end
