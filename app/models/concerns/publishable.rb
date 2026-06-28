# A catalog record is publicly visible only once approved. "Approved" is
# derived from its catalog ModerationItem: admins and verified brand owners
# create entries directly (no item is filed), so they're visible immediately,
# while a member's new entry carries a pending item and stays hidden from the
# public catalog until a moderator approves it.
module Publishable
  extend ActiveSupport::Concern

  included do
    has_many :moderation_items, as: :subject, dependent: :destroy

    # The public catalog: records with no still-unapproved catalog item — i.e.
    # no catalog item at all (created directly), or one that's been approved.
    scope :published, -> {
      where.not(
        id: ModerationItem.where(subject_type: polymorphic_name, kind: :catalog)
                          .where.not(status: :approved)
                          .select(:subject_id)
      )
    }
  end

  # The catalog moderation item gating this record's visibility, if any. Not
  # memoized: a moderator approving it elsewhere should reflect immediately.
  def catalog_moderation_item
    moderation_items.where(kind: :catalog).order(:id).first
  end

  def published?
    item = catalog_moderation_item
    item.nil? || item.status_approved?
  end

  # Who may view the record's own page before it's published: moderators (to
  # review it) and the member who submitted it. Everyone else gets a 404.
  def visible_to?(user)
    return true if published?
    return true if user&.can_moderate?

    catalog_moderation_item&.submitter_id == user&.id && user.present?
  end
end
