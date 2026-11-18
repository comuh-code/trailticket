module Trailticket
  class Ticket < ApplicationRecord
    # Default statuses. The list in use is Trailticket.config.statuses.
    STATUSES = Configuration::DEFAULT_STATUSES
    PRIORITIES = %w[low normal high urgent].freeze

    belongs_to :author, polymorphic: true
    belongs_to :assignee, polymorphic: true, optional: true
    belongs_to :closed_by, polymorphic: true, optional: true
    # Optional link to something in the host app (an account, a project...).
    belongs_to :subject, polymorphic: true, optional: true

    has_many :messages, -> { order(:created_at) }, dependent: :destroy, inverse_of: :ticket
    has_many :events, -> { order(:created_at, :id) }, dependent: :delete_all, inverse_of: :ticket

    # Needs Active Storage in the host app; without it tickets simply have no screenshot.
    has_one_attached :screenshot if respond_to?(:has_one_attached)

    attribute :context, :json, default: -> { {} }

    attribute :status, :string, default: -> { Trailticket.config.statuses.first }
    enum :priority, PRIORITIES.index_with(&:itself), prefix: true, default: "normal", validate: true

    validates :title, presence: true, length: { maximum: 200 }
    validates :body, presence: true
    validates :status, inclusion: { in: ->(_ticket) { Trailticket.config.statuses } }

    scope :active, -> { where.not(status: final_status) }

    before_save :sync_closed_at
    # In the same transaction as the change, so the history never misses one.
    after_update :record_history, if: :history?
    after_create_commit :notify_created
    after_update_commit :notify_status_change, if: :saved_change_to_status?

    def self.initial_status
      Trailticket.config.statuses.first
    end

    def self.final_status
      Trailticket.config.statuses.last
    end

    def final_status?
      status == self.class.final_status
    end
    alias status_closed? final_status?

    (STATUSES - ["closed"]).each do |name|
      define_method(:"status_#{name}?") { status == name }
    end

    # False until the app runs the migration that creates trailticket_events.
    def self.history?
      Event.table_exists?
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

    def history?
      self.class.history?
    end

    def record_history
      record_event("status_changed", *saved_change_to_status) if saved_change_to_status?
      record_event("priority_changed", *saved_change_to_priority) if saved_change_to_priority?
      return unless saved_change_to_assignee_id? || saved_change_to_assignee_type?

      before = [assignee_type_before_last_save, assignee_id_before_last_save]
      record_event("assignee_changed", record_ref(*before), record_ref(assignee_type, assignee_id))
    end

    def record_event(action, from, to)
      events.create!(action: action, actor: Trailticket::Current.actor,
                     data: { "from" => from, "to" => to })
    end

    def record_ref(type, id)
      { "type" => type, "id" => id } if type && id
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
