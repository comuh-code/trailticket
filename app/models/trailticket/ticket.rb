module Trailticket
  class Ticket < ApplicationRecord
    STATUSES = %w[open in_progress waiting closed].freeze
    PRIORITIES = %w[low normal high urgent].freeze

    belongs_to :author, polymorphic: true
    belongs_to :assignee, polymorphic: true, optional: true
    belongs_to :closed_by, polymorphic: true, optional: true
    # Optional link to something in the host app (an account, a project...).
    belongs_to :subject, polymorphic: true, optional: true

    has_many :messages, -> { order(:created_at) }, dependent: :destroy, inverse_of: :ticket

    # Needs Active Storage in the host app; without it tickets simply have no screenshot.
    has_one_attached :screenshot if respond_to?(:has_one_attached)

    attribute :context, :json, default: -> { {} }

    enum :status, STATUSES.index_with(&:itself), prefix: true, default: "open", validate: true
    enum :priority, PRIORITIES.index_with(&:itself), prefix: true, default: "normal", validate: true

    validates :title, presence: true, length: { maximum: 200 }
    validates :body, presence: true

    scope :active, -> { where.not(status: "closed") }

    before_save :sync_closed_at
    after_create_commit :notify_created
    after_update_commit :notify_status_change, if: :saved_change_to_status?

    def self.screenshots?
      method_defined?(:screenshot)
    end

    def screenshot?
      self.class.screenshots? && screenshot.attached?
    end

    def close!(by:)
      update!(status: "closed", closed_by: by)
    end

    def reopen!
      update!(status: "open")
    end

    private

    def sync_closed_at
      return unless will_save_change_to_status?

      if status_closed?
        self.closed_at ||= Time.current
      else
        self.closed_at = nil
        self.closed_by = nil
      end
    end

    def notify_created
      Trailticket.config.on_ticket_created&.call(self)
    end

    def notify_status_change
      from, to = saved_change_to_status
      Trailticket.config.on_status_changed&.call(self, from, to)
    end
  end
end
