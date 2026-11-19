# frozen_string_literal: true

class Trailticket::TicketPolicy
  attr_reader :user, :ticket

  def initialize(user, ticket = nil)
    @user = user
    @ticket = ticket
  end

  def opener?
    allowed?(:can_open)
  end

  def manage?
    allowed?(:can_manage)
  end

  def access?
    opener? || manage?
  end

  def create?
    opener?
  end

  def show?
    manage? || author?
  end

  def reply?
    manage? || (author? && !ticket.status_closed?)
  end

  def author?
    !!(user && ticket && ticket.author == user)
  end

  def to_h
    { open: opener?, manage: manage?, reply: ticket ? reply? : nil }.compact
  end

  class Scope
    def initialize(user)
      @user = user
    end

    def resolve
      policy = Trailticket::TicketPolicy.new(@user)
      return Trailticket::Ticket.all if policy.manage?
      return Trailticket::Ticket.where(author: @user) if policy.opener?

      Trailticket::Ticket.none
    end
  end

  private

  def allowed?(key)
    return false unless user

    !!Trailticket.config.public_send(key)&.call(user)
  end
end
