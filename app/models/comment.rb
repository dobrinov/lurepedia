class Comment < ApplicationRecord
  belongs_to :catch, counter_cache: :comments_count
  belongs_to :user

  validates :body, presence: true

  scope :chronological, -> { order(:created_at) }
end
