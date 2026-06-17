class ModerationItem < ApplicationRecord
  belongs_to :subject, polymorphic: true
  belongs_to :submitter, class_name: "User", optional: true
  belongs_to :reviewer, class_name: "User", optional: true
  belongs_to :revision, optional: true

  enum :kind, { catch: 0, edit: 1, catalog: 2, claim: 3, report: 4 }, prefix: true
  enum :status, { pending: 0, approved: 1, rejected: 2 }, prefix: true

  scope :pending, -> { where(status: :pending) }
  scope :newest_first, -> { order(created_at: :desc) }
  scope :of_kind, ->(k) { where(kind: k) }

  # Moderators can act on most items; claims & new catalog entries need an admin.
  def actionable_by?(user)
    return false unless user&.can_moderate?
    return true if user.admin?

    mod_actionable?
  end

  def approve!(reviewer)
    update!(status: :approved, reviewer: reviewer, reviewed_at: Time.current)
  end

  def reject!(reviewer)
    update!(status: :rejected, reviewer: reviewer, reviewed_at: Time.current)
  end

  def undo!
    update!(status: :pending, reviewer: nil, reviewed_at: nil)
  end
end
