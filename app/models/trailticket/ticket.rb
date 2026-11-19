module Trailticket
  class Ticket < ApplicationRecord
    include Archiving
    include History

    # Default statuses. The list in use is Trailticket.config.statuses.
    STATUSES = Configuration::DEFAULT_STATUSES
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

    attribute :status, :string, default: -> { Trailticket.config.initial_status }
    enum :priority, PRIORITIES.index_with(&:itself), prefix: true, default: "normal", validate: true

    validates :title, presence: true, length: { maximum: 200 }
    validates :body, presence: true
    validates :status, inclusion: { in: ->(_ticket) { Trailticket.config.statuses } }

    scope :active, -> { where.not(status: final_statuses) }

    before_save :sync_closed_at
    before_save :remember_actor, if: :will_save_change_to_status?
    after_create_commit :notify_created
    after_update_commit :notify_status_change, if: :saved_change_to_status?

    def self.initial_status
      Trailticket.config.initial_status
    end

    def self.final_statuses
      Trailticket.config.final_statuses
    end

    # The final status used by close! (the first of final_statuses).
    def self.final_status
      final_statuses.first
    end

    def final_status?
      self.class.final_statuses.include?(status)
    end
    alias status_closed? final_status?

    # Moving from a non-final status into a final one.
    def closing?
      will_save_change_to_status? && final_status? &&
        self.class.final_statuses.exclude?(status_in_database)
    end

    (STATUSES - ["closed"]).each do |name|
      define_method(:"status_#{name}?") { status == name }
    end

    def self.screenshots?
      method_defined?(:screenshot)
    end

    def screenshot?
      self.class.screenshots? && screenshot.attached?
    end

    def close!(by:)
      update!(status: self.class.final_status, closed_by: by)
    end

    def reopen!
      update!(status: self.class.initial_status)
    end

    private

    def sync_closed_at
      return unless will_save_change_to_status?

      if final_status?
        self.closed_at ||= Time.current
      else
        self.closed_at = nil
        self.closed_by = nil
      end
    end

    def remember_actor
      @status_actor = Trailticket::Current.actor
    end

    def notify_created
      Trailticket.config.on_ticket_created&.call(self)
    end

    def notify_status_change
      hook = Trailticket.config.on_status_changed
      return unless hook

      from, to = saved_change_to_status
      args = [self, from, to, @status_actor]
      # Hooks written for 0.3 take (ticket, from, to).
      hook.call(*(hook.arity.between?(0, 3) ? args.first(hook.arity) : args))
    end
  end
end
