# frozen_string_literal: true

class Trailticket::OpenTicket
  RESERVED_CONTEXT_KEYS = %w[page trail fields errors].freeze
  OPTIONS = %i[priority context screenshot subject user_agent page_url metadata].freeze

  def self.call(**attributes)
    new(**attributes).call
  end

  def initialize(author:, title:, body:, **options)
    options.assert_valid_keys(*OPTIONS)
    OPTIONS.each { |name| instance_variable_set(:"@#{name}", options[name]) }
    @attributes = { author: author, title: title, body: body, subject: @subject }
    @metadata = normalize_metadata(@metadata)
  end

  def call
    ticket = Trailticket::Ticket.new(@attributes)
    assign_priority(ticket)
    ticket.context = build_context
    ticket.page_url = page_url_for(ticket.context)

    error = attach_screenshot(ticket)
    return screenshot_rejected(ticket, error) if error

    ticket.save
    ticket
  end

  private

  def build_context
    context = Trailticket::ContextSanitizer.call(@context)
    if @user_agent.present?
      context['page'] ||= {}
      context['page']['user_agent'] ||= @user_agent.to_s[0, 500]
    end
    context.merge(@metadata)
  end

  def page_url_for(context)
    return Trailticket::ContextSanitizer.clean_url(@page_url) if @page_url.present?

    context.dig('page', 'url')
  end

  def normalize_metadata(metadata)
    metadata = (metadata || {}).to_h.deep_stringify_keys
    reserved = metadata.keys & RESERVED_CONTEXT_KEYS
    if reserved.any?
      raise ArgumentError, "metadata cannot use reserved context keys: #{reserved.join(', ')}"
    end

    metadata
  end

  def assign_priority(ticket)
    if Trailticket.config.triage
      ticket.suggested_priority = @priority.to_s.presence_in(Trailticket::Ticket::PRIORITIES)
    elsif @priority.present?
      ticket.priority = @priority
    end
  end

  def screenshot_rejected(ticket, error)
    ticket.validate
    ticket.errors.add(:screenshot, error)
    ticket
  end

  def attach_screenshot(ticket)
    return if @screenshot.blank? || !Trailticket::Ticket.screenshots?

    ticket.screenshot.attach(**Trailticket::ScreenshotDecoder.call(@screenshot))
    nil
  rescue Trailticket::InvalidScreenshot => e
    e.message
  end
end
