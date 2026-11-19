# frozen_string_literal: true

class Trailticket::TicketSerializer
  FIELDS = %i[id title body status priority suggested_priority page_url].freeze
  PEOPLE = %i[author assignee closed_by].freeze
  TIMES = %i[closed_at archived_at created_at updated_at].freeze

  def initialize(ticket, policy:, screenshot_url: nil, details: false)
    @ticket = ticket
    @policy = policy
    @screenshot_url = screenshot_url
    @details = details
  end

  def as_json(*)
    json = attributes
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

  def attributes
    json = FIELDS.index_with { |name| @ticket.public_send(name) }
    PEOPLE.each { |name| json[name] = user(@ticket.public_send(name)) }
    TIMES.each { |name| json[name] = @ticket.public_send(name)&.iso8601 }
    json.merge(screenshot_url: (@screenshot_url if @ticket.screenshot?),
               permissions: { reply: @policy.reply?, manage: @policy.manage? })
  end

  def user(record) = self.class.user(record)

  def message_json(message) = self.class.message(message)

  def messages
    scope = @ticket.messages.includes(:author)
    @policy.manage? ? scope : scope.public_only
  end
end
