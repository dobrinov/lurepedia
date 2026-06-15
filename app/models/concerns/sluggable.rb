module Sluggable
  extend ActiveSupport::Concern

  included do
    before_validation :ensure_slug
    validates :slug, presence: true, uniqueness: true
  end

  def to_param
    slug
  end

  private

  def ensure_slug
    return if slug.present?

    base = slug_source.to_s.parameterize
    return if base.blank?

    candidate = base
    i = 2
    while self.class.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{i}"
      i += 1
    end
    self.slug = candidate
  end

  # Override in models to choose what the slug is generated from.
  def slug_source
    try(:name) || try(:model)
  end
end
