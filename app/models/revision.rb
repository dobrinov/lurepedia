class Revision < ApplicationRecord
  belongs_to :subject, polymorphic: true
  belongs_to :user, optional: true

  validates :summary, presence: true

  scope :chronological, -> { order(:created_at) }
  scope :newest_first, -> { order(created_at: :desc) }
end
