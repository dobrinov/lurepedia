module Editable
  extend ActiveSupport::Concern

  included do
    helper_method :edit_affordance_label
  end

  private

  # Admins and verified brand owners edit directly (no review); everyone else
  # files a reviewed suggestion.
  def commit_edit(record, attrs, name, redirect_path)
    return unless require_contribution(:catalog)

    attrs = persist_attachments(record, attrs)
    changeset = build_changeset(record, attrs)

    if can_edit_directly?(record)
      if record.update(attrs)
        record.revisions.create!(user: current_user, summary: "Edited #{name}", changeset: changeset)
        redirect_to redirect_path, notice: t("contribute.edit_saved")
      else
        flash.now[:alert] = record.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    else
      revision = record.revisions.create!(user: current_user, summary: "Suggested an edit to #{name}", changeset: changeset, applied: false)
      ModerationItem.create!(subject: record, kind: :edit, submitter: current_user, revision: revision)
      redirect_to redirect_path, notice: t("contribute.suggested")
    end
  end

  # Field-level before/after map for the proposed attrs, keyed by attribute:
  # { "field" => [ old_value, new_value ] }. Only genuinely changed fields are
  # kept, and values are cast to the column's type so a "100" param compares
  # equal to an integer 100.
  def build_changeset(record, attrs)
    attrs.to_h.each_with_object({}) do |(key, value), diff|
      next unless record.respond_to?(key)

      if record.class.attachment_reflections.key?(key.to_s)
        attachment = record.public_send(key)
        old_value = attachment.attached? ? attachment.blob.signed_id : nil
        new_value = value.presence
      elsif key.to_s.end_with?("_ids")
        old_value = Array(record.public_send(key)).map(&:to_i).sort
        new_value = Array(value).reject(&:blank?).map(&:to_i).sort
      else
        type = record.class.type_for_attribute(key.to_s)
        old_value = record.public_send(key)
        new_value = type ? type.cast(value) : value
      end
      diff[key.to_s] = [ old_value, new_value ] unless old_value == new_value
    end
  end

  # Uploaded files can't survive in a JSON changeset, so persist each uploaded
  # attachment to its own blob now and pass the blob's signed id forward in
  # place of the raw file. The signed id round-trips through the changeset, so a
  # suggested photo edit can be attached when a moderator approves it — long
  # after the upload's tempfile is gone — and rolled back on undo. A blank
  # attachment param is dropped so an untouched file field doesn't clear the
  # existing image.
  def persist_attachments(record, attrs)
    attrs = attrs.to_h
    record.class.attachment_reflections.each_key do |name|
      next unless attrs.key?(name)

      value = attrs[name]
      if value.blank?
        attrs.delete(name)
      elsif value.respond_to?(:open)
        blob = ActiveStorage::Blob.create_and_upload!(
          io: value.open, filename: value.original_filename, content_type: value.content_type
        )
        attrs[name] = blob.signed_id
      end
    end
    attrs
  end

  # Direct, unreviewed edits are reserved for admins and the verified owner of
  # the brand the record belongs to.
  def can_edit_directly?(record)
    return false unless current_user
    return true if current_user.admin?

    owning_brand(record)&.managed_by?(current_user) || false
  end

  # Whether the current user may publish a NEW catalog record under this brand
  # without review — admins and the brand's verified owner. Mirrors
  # can_edit_directly? for records that don't exist yet.
  def can_add_directly?(brand)
    return false unless current_user
    return true if current_user.admin?

    brand&.managed_by?(current_user) || false
  end

  # The brand whose ownership confers direct-edit rights over this record, if
  # any. Shared catalog records (e.g. species) have no owning brand.
  def owning_brand(record)
    case record
    when Brand then record
    when Lure then record.brand
    when Variant, Build then record.lure&.brand
    end
  end

  # Label shown on edit affordances: "Edit" for those who can edit the record
  # directly (admins, brand owners), "Suggest an edit" for everyone else.
  # Without a record it falls back to the admin check for non record-specific
  # affordances.
  def edit_affordance_label(record = nil)
    direct = record ? can_edit_directly?(record) : current_user&.admin?
    direct ? t("common.edit") : t("contribute.suggest_edit")
  end
end
