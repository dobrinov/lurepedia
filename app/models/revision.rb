class Revision < ApplicationRecord
  belongs_to :subject, polymorphic: true
  belongs_to :user, optional: true

  validates :summary, presence: true

  scope :chronological, -> { order(:created_at) }
  scope :newest_first, -> { order(created_at: :desc) }
  # Revisions that have actually landed on the record — the public edit history.
  # A pending suggestion's revision is excluded until a moderator approves it.
  scope :applied, -> { where(applied: true) }

  # A field-level edit (has a recorded before/after changeset), as opposed to a
  # creation entry or a legacy revision recorded before changesets were tracked.
  def edit?
    changeset.present?
  end

  # Normalized list of changed fields for diff rendering:
  # [ { field:, old:, new: }, ... ]
  def field_changes
    (changeset || {}).map do |field, (old_value, new_value)|
      { field: field, old: old_value, new: new_value }
    end
  end
end
