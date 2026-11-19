# frozen_string_literal: true

module Trailticket::Ticket::Archiving
  extend ActiveSupport::Concern

  included do
    scope :archived, -> { where.not(archived_at: nil) }
    scope :unarchived, -> { where(archived_at: nil) }

    before_validation :unarchive_when_reopened
    validate :archived_only_when_final
  end

  def archived?
    archived_at.present?
  end

  def archivable?
    final_status? && !archived?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def unarchive!
    update!(archived_at: nil)
  end

  private

  def unarchive_when_reopened
    self.archived_at = nil if will_save_change_to_status? && !final_status?
  end

  def archived_only_when_final
    return unless archived? && !final_status?

    errors.add(:archived_at, 'can only be set when the ticket is in a final status')
  end
end
