module Sluggable
  extend ActiveSupport::Concern

  included do
    before_validation :ensure_slug
    validates :slug, uniqueness: true
    validate :slug_present
  end

  def to_param
    slug
  end

  private

  # The slug is auto-derived from `slug_source` (see ensure_slug). When it comes
  # out blank the cause is a blank source, which the model reports through its
  # own presence validation (e.g. "Name can't be blank") — so we only flag the
  # slug itself when the source had content yet still produced no slug, avoiding
  # a redundant, internal-sounding "Slug can't be blank".
  def slug_present
    return if slug.present?

    errors.add(:slug, :blank) if slug_source.present?
  end

  def ensure_slug
    return if slug.present?

    base = slug_source.to_s.parameterize
    return if base.blank?

    suffix = slug_suffix
    base = "#{base}-#{suffix}" if suffix.present?

    candidate = base
    i = 2
    while self.class.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{i}"
      i += 1
    end
    self.slug = candidate
  end

  # Optional per-model token appended to the slug base (nil = none).
  def slug_suffix
    nil
  end

  # Override in models to choose what the slug is generated from.
  def slug_source
    try(:name) || try(:model)
  end
end
