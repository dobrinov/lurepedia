class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :favoritable, polymorphic: true

  # Only these types may be favorited.
  FAVORITABLE_TYPES = %w[Species Lure Shop].freeze

  validates :user_id, uniqueness: { scope: [ :favoritable_type, :favoritable_id ] }
  validates :favoritable_type, inclusion: { in: FAVORITABLE_TYPES }
end
