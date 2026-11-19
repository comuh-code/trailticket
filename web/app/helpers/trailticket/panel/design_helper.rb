# frozen_string_literal: true

# Theme, icons and small visual pieces shared by every page of the panel and by
# its design system page. Built with content_tag, so text is always escaped.
module Trailticket::Panel::DesignHelper
  THEMES = %w[auto light dark].freeze

  WARNING_PATH = 'M12 9v4M12 17h.01M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17' \
                 'a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z'

  # Stroke icons (24×24 viewBox), drawn with currentColor.
  ICONS = {
    urgent: WARNING_PATH,
    high: 'M12 19V5M5 12l7-7 7 7',
    normal: 'M5 12h14',
    low: 'M12 5v14M19 12l-7 7-7-7',
    none: 'M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3M12 17h.01',
    back: 'M19 12H5M12 19l-7-7 7-7',
    pin: 'M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11zM12 12a2 2 0 1 0 0-4 2 2 0 0 0 0 4z',
    lock: 'M5 11h14v10H5zM8 11V7a4 4 0 0 1 8 0v4',
    error: 'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20zM15 9l-6 6M9 9l6 6',
    warning: WARNING_PATH
  }.freeze

  # Theme of the panel (data-tt-theme): config.web_theme, "auto" when unset or unknown.
  def web_theme
    theme = Trailticket.config.web_theme.to_s
    THEMES.include?(theme) ? theme : 'auto'
  end

  # Extra stylesheet from the host, loaded after the panel's own CSS to override tokens.
  def web_stylesheet_url
    value = Trailticket.config.web_stylesheet
    value = value.call(request) if value.respond_to?(:call)
    value.presence&.to_s
  end

  def tt_icon?(name)
    ICONS.key?(name.to_sym)
  end

  def tt_icon(name, css: nil)
    path = ICONS.fetch(name.to_sym)
    content_tag(:svg, content_tag(:path, nil, d: path),
                class: ['tt-icon', css].compact.join(' '), viewBox: '0 0 24 24',
                fill: 'none', stroke: 'currentColor', 'stroke-width': '2.4',
                'stroke-linecap': 'round', 'stroke-linejoin': 'round',
                'aria-hidden': 'true', focusable: 'false')
  end

  # initial (where tickets start), work, done (first final) or final (other finals).
  def status_kind(status)
    status = status.to_s
    finals = Trailticket::Ticket.final_statuses
    return 'initial' if status == Trailticket::Ticket.initial_status
    return 'work' unless finals.include?(status)

    status == finals.first ? 'done' : 'final'
  end

  def status_dot(status)
    tag.span(class: "tt-dot tt-dot-#{status_kind(status)}", 'aria-hidden': 'true')
  end

  # Two letters for the avatar circle: "Olivia Souza" → "OS", "Olivia" → "OL".
  def initials(label)
    words = label.to_s.scan(/[[:alnum:]]+/)
    return '?' if words.empty?

    letters = words.size > 1 ? words.first(2).pluck(0).join : words.first[0, 2]
    letters.upcase
  end

  def avatar(label, css: nil)
    tag.span(initials(label), class: ['tt-avatar', css].compact.join(' '), 'aria-hidden': 'true')
  end
end
