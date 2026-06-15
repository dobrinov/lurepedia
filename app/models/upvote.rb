class Upvote < ApplicationRecord
  belongs_to :user
  belongs_to :catch, counter_cache: :upvotes_count

  validates :user_id, uniqueness: { scope: :catch_id }
end
