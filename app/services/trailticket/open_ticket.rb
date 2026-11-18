module Trailticket
  class OpenTicket
    RESERVED_CONTEXT_KEYS = %w[page trail fields errors].freeze

    def self.call(**attributes)
      new(**attributes).call
    end

    def initialize(author:, title:, body:, priority: nil, context: nil, screenshot: nil,
                   subject: nil, user_agent: nil, page_url: nil, metadata: {})
      @author = author
      @title = title
      @body = body
      @priority = priority
      @context = context
      @screenshot = screenshot
      @subject = subject
      @user_agent = user_agent
      @page_url = page_url
      @metadata = normalize_metadata(metadata)
    end

    def call
      ticket = Ticket.new(author: @author, title: @title, body: @body, subject: @subject)
      ticket.priority = @priority if @priority.present?
      ticket.context = build_context
      ticket.page_url = page_url_for(ticket.context)

      screenshot_error = attach_screenshot(ticket)
      if screenshot_error
        ticket.validate
        ticket.errors.add(:screenshot, screenshot_error)
        return ticket
      end

      ticket.save
      ticket
    end

    private

    def build_context
      context = ContextSanitizer.call(@context)
      if @user_agent.present?
        context["page"] ||= {}
        context["page"]["user_agent"] ||= @user_agent.to_s[0, 500]
      end
      # metadata is trusted server data: merged after sanitization, never through it.
      context.merge(@metadata)
    end

    def page_url_for(context)
      return ContextSanitizer.clean_url(@page_url) if @page_url.present?

      context.dig("page", "url")
    end

    def normalize_metadata(metadata)
      metadata = (metadata || {}).to_h.deep_stringify_keys
      reserved = metadata.keys & RESERVED_CONTEXT_KEYS
      if reserved.any?
        raise ArgumentError, "metadata cannot use reserved context keys: #{reserved.join(', ')}"
      end

      metadata
    end

    def attach_screenshot(ticket)
      return if @screenshot.blank? || !Ticket.screenshots?

      ticket.screenshot.attach(**ScreenshotDecoder.call(@screenshot))
      nil
    rescue InvalidScreenshot => e
      e.message
    end
  end
end
