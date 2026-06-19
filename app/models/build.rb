class Build < ApplicationRecord
  belongs_to :lure
  has_many :catches, dependent: :destroy
  has_many :variant_builds, dependent: :destroy
  has_many :variants, through: :variant_builds
  has_many :revisions, as: :subject, dependent: :destroy

  enum :action, { none: 0, suspending: 1, floating: 2, sinking: 3 }, prefix: :action
  enum :water, { fresh: 0, salt: 1, both: 2 }, prefix: :water

  validates :name, presence: true

  scope :ordered, -> { order(:position, :id) }
end
