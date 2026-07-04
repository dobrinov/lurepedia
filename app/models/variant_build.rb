class VariantBuild < ApplicationRecord
  belongs_to :variant
  belongs_to :build

  validates :variant_id, uniqueness: { scope: :build_id }
end
