# A non-destructive crop for the record's `photo` attachment: a rectangle in
# original-image pixel coordinates stored in photo_crop_x/y/w/h. The original
# file is never modified — rendering applies the crop as a leading variant
# transformation (ApplicationHelper#cropped_photo), so clearing the fields
# restores the full frame and Active Storage regenerates variants either way.
module Croppable
  extend ActiveSupport::Concern

  CROP_FIELDS = %i[photo_crop_x photo_crop_y photo_crop_w photo_crop_h].freeze

  included do
    validate :crop_complete_and_positive
    before_save :reset_crop_on_new_photo
  end

  def photo_crop?
    CROP_FIELDS.all? { |field| self[field].present? }
  end

  # ImageMagick crop geometry ("WxH+X+Y") for the stored rectangle, or nil
  # when the photo is uncropped.
  def photo_crop_geometry
    return unless photo_crop?

    "#{photo_crop_w}x#{photo_crop_h}+#{photo_crop_x}+#{photo_crop_y}"
  end

  private

  # The crop is all-or-none and must have positive size. A rectangle reaching
  # past the image edge is fine — ImageMagick clips it.
  def crop_complete_and_positive
    values = CROP_FIELDS.map { |field| self[field] }
    return if values.all?(&:nil?)

    if values.any?(&:nil?) || photo_crop_w < 1 || photo_crop_h < 1 || photo_crop_x.negative? || photo_crop_y.negative?
      errors.add(:base, I18n.t("crop.invalid"))
    end
  end

  # A crop describes one specific image, so a new photo invalidates it. Keep
  # it only when the same save also rewrites the crop (e.g. an approved
  # changeset carrying both photo and crop).
  def reset_crop_on_new_photo
    return unless attachment_changes["photo"]
    return if CROP_FIELDS.any? { |field| will_save_change_to_attribute?(field) }

    CROP_FIELDS.each { |field| self[field] = nil }
  end
end
