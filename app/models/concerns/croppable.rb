# Presentation settings for the record's `photo` attachment, all
# non-destructive — the original file is never modified:
#
# - A crop rectangle in original-image pixel coordinates
#   (photo_crop_x/y/w/h), applied as a leading variant transformation
#   (ApplicationHelper#cropped_photo). Clearing the fields restores the full
#   frame; Active Storage regenerates variants either way.
# - An optional tile background override (photo_bg_color, "#rrggbb") shown
#   behind letterboxed contain-fit renders in place of the color measured
#   from the image by TileBackgroundAnalyzer.
module Croppable
  extend ActiveSupport::Concern

  CROP_FIELDS = %i[photo_crop_x photo_crop_y photo_crop_w photo_crop_h].freeze
  HEX_COLOR = /\A#\h{6}\z/

  included do
    normalizes :photo_bg_color, with: ->(color) { color.presence&.downcase }
    validates :photo_bg_color, format: { with: HEX_COLOR }, allow_blank: true
    validate :crop_complete_and_positive
    before_save :reset_photo_presentation_on_new_photo
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

  # The color to paint behind letterboxed renders of the photo: the manual
  # override when set, otherwise the border color measured at analysis time.
  # The analyzer stores false for "no usable color" — .presence maps it to nil.
  def photo_background_color
    photo_bg_color.presence ||
      (photo.blob&.metadata&.[]("background_color") if photo.attached?).presence
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

  # Crop and background color describe one specific image, so a new photo
  # invalidates them. Each survives only when the same save also rewrites it
  # (e.g. an approved changeset carrying photo and crop together).
  def reset_photo_presentation_on_new_photo
    return unless attachment_changes["photo"]

    unless CROP_FIELDS.any? { |field| will_save_change_to_attribute?(field) }
      CROP_FIELDS.each { |field| self[field] = nil }
    end
    self.photo_bg_color = nil unless will_save_change_to_attribute?(:photo_bg_color)
  end
end
