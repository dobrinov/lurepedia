# A symmetric "these two lures are comparable" cross-reference, typically
# spanning brands (look-alike minnows sold under different names). One row per
# pair, stored lower-id-first so the reverse duplicate collides with the
# unique index instead of needing a two-way uniqueness check.
#
# Links are catalog entries: a member's link is created live but hidden until
# its moderation item is approved (Publishable). Only admins add them without
# review — a link touches two brands, so even a verified owner of one brand
# doesn't get an unreviewed write that name-drops another brand's lure.
class LureLink < ApplicationRecord
  include Publishable

  belongs_to :lure
  belongs_to :related_lure, class_name: "Lure"

  before_validation :normalize_direction

  validates :related_lure_id, uniqueness: { scope: :lure_id }
  validate :not_self_referential

  # Both directions of the symmetric pair, as link rows.
  scope :involving, ->(lure) { where(lure_id: lure.id).or(where(related_lure_id: lure.id)) }

  # The far end of the link as seen from the given lure.
  def other_lure(from)
    lure_id == from.id ? related_lure : lure
  end

  private

  def normalize_direction
    return unless lure_id && related_lure_id && lure_id > related_lure_id

    self.lure_id, self.related_lure_id = related_lure_id, lure_id
  end

  def not_self_referential
    errors.add(:related_lure, :invalid) if lure_id.present? && lure_id == related_lure_id
  end
end
