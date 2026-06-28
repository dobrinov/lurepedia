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
  # Nobody can action their own submission — admins' edits skip the queue entirely.
  def actionable_by?(user)
    return false unless user&.can_moderate?
    return false if submitter_id == user.id

    return true if user.admin?

    mod_actionable?
  end

  # Approving a suggested edit is what actually lands it on the record: the
  # proposed changeset is applied and its revision becomes part of the public
  # history. Rejecting or undoing an already-applied edit rolls it back.
  def approve!(reviewer)
    transaction do
      apply_edit!(:new) if edits_a_record?
      update!(status: :approved, reviewer: reviewer, reviewed_at: Time.current)
    end
  end

  def reject!(reviewer)
    transaction do
      apply_edit!(:old) if edits_a_record? && status_approved?
      update!(status: :rejected, reviewer: reviewer, reviewed_at: Time.current)
    end
  end

  def undo!
    transaction do
      apply_edit!(:old) if edits_a_record? && status_approved?
      update!(status: :pending, reviewer: nil, reviewed_at: nil)
    end
  end

  private

  # Only edit suggestions carry a changeset to apply; catches, new catalog
  # entries, claims and reports are acted on live and just flip status.
  def edits_a_record?
    kind_edit? && revision&.changeset.present?
  end

  # Writes one side of the changeset (:new to apply, :old to roll back) onto the
  # subject and keeps the revision's `applied` flag in step, so it appears in —
  # or disappears from — the public history accordingly.
  def apply_edit!(side)
    index = side == :new ? 1 : 0
    attrs = revision.changeset.transform_values { |pair| pair[index] }
    revision.subject.update!(attrs)
    revision.update!(applied: side == :new)
  end
end
