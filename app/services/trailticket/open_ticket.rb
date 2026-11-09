module Trailticket
  class OpenTicket
    def self.call(**attributes)
      new(**attributes).call
    end

    def initialize(author:, title:, body:, priority: nil, context: nil, screenshot: nil,
                   subject: nil, user_agent: nil)
      @author = author
      @title = title
      @body = body
      @priority = priority
      @context = context
      @screenshot = screenshot
      @subject = subject
      @user_agent = user_agent
    end

    def call
      ticket = Ticket.new(author: @author, title: @title, body: @body, subject: @subject)
      ticket.priority = @priority if @priority.present?
      ticket.context = build_context
      ticket.page_url = ticket.context.dig("page", "url")

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
      context
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
