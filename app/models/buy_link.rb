class BuyLink < ApplicationRecord
  belongs_to :lure
  belongs_to :shop

  delegate :promoted?, :name, to: :shop, prefix: false
end
