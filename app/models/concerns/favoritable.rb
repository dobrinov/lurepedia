module Favoritable
  extend ActiveSupport::Concern

  included do
    has_many :favorites, as: :favoritable, dependent: :destroy
  end

  def favorited_by?(user)
    return false unless user

    favorites.exists?(user_id: user.id)
  end
end
