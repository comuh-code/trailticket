module Trailticket
  class TicketSerializer
    def initialize(ticket, policy:, screenshot_url: nil, details: false)
      @ticket = ticket
      @policy = policy
      @screenshot_url = screenshot_url
      @details = details
    end

    def as_json(*)
      json = {
        id: @ticket.id,
        title: @ticket.title,
        body: @ticket.body,
        status: @ticket.status,
        priority: @ticket.priority,
        page_url: @ticket.page_url,
        author: user(@ticket.author),
        assignee: user(@ticket.assignee),
        closed_by: user(@ticket.closed_by),
        closed_at: @ticket.closed_at&.iso8601,
        created_at: @ticket.created_at&.iso8601,
        updated_at: @ticket.updated_at&.iso8601,
        screenshot_url: (@screenshot_url if @ticket.screenshot?),
        permissions: { reply: @policy.reply?, manage: @policy.manage? }
      }
      return json unless @details

      json.merge(context: @ticket.context, messages: messages.map { |message| message_json(message) })
    end

    def self.user(user)
      user ? Trailticket.config.user_json.call(user) : nil
    end

    def self.message(message)
      {
        id: message.id,
        body: message.body,
        internal: message.internal,
        author: user(message.author),
        created_at: message.created_at&.iso8601
      }
    end

    private

    def user(record) = self.class.user(record)

    def message_json(message) = self.class.message(message)

    def messages
      scope = @ticket.messages.includes(:author)
      @policy.manage? ? scope : scope.public_only
    end
  end
end
