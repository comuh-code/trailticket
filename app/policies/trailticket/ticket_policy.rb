module Trailticket
  # Roles come from the host app (config.can_open / config.can_manage);
  # this class only combines them with ticket authorship.
  class TicketPolicy
    attr_reader :user, :ticket

    def initialize(user, ticket = nil)
      @user = user
      @ticket = ticket
    end

    def opener?
      check(:can_open)
    end

    def manage?
      check(:can_manage)
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

    # Authors can reply while the ticket is not closed.
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
        policy = TicketPolicy.new(@user)
        return Ticket.all if policy.manage?
        return Ticket.where(author: @user) if policy.opener?

        Ticket.none
      end
    end

    private

    def check(key)
      return false unless user

      !!Trailticket.config.public_send(key)&.call(user)
    end
  end
end
