class LureTechnique < ApplicationRecord
  belongs_to :lure
  belongs_to :technique

  validates :technique_id, uniqueness: { scope: :lure_id }
end
