module Trailticket
  class Message < ApplicationRecord
    belongs_to :ticket, touch: true, inverse_of: :messages
    belongs_to :author, polymorphic: true

    validates :body, presence: true

    # Internal notes are only visible to whoever handles tickets.
    scope :public_only, -> { where(internal: false) }

    after_create_commit :notify_created

    private

    def notify_created
      Trailticket.config.on_message_created&.call(self)
    end
  end
end
