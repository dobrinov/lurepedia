module RevisionsHelper
  # Human label for a changed attribute, e.g. "depth_min_cm" -> "Depth min (cm)".
  def diff_field_label(field)
    key = field.to_s
    return t("revision.field.#{key}") if I18n.exists?("revision.field.#{key}")

    key.sub(/_ids\z/, "s").sub(/_id\z/, "").sub(/_cm\z/, " (cm)").sub(/_mm\z/, " (mm)").sub(/_g\z/, " (g)").humanize
  end

  # Path to the record a revision belongs to (nil for subjects with no show page).
  def revision_subject_path(subject)
    case subject
    when Lure then lure_path(subject)
    when Brand then brand_path(subject)
    when Species then species_path(subject)
    when Catch then catch_path(subject)
    when Variant, Build then edit_lure_path(subject.lure)
    end
  end

  # Human label for a revision's subject record.
  def revision_subject_label(subject)
    case subject
    when Lure then subject.title
    when Brand, Shop then subject.name
    when Species then subject.common_name
    when Variant, Build then "#{subject.lure.title} — #{subject.name}"
    else subject.class.name
    end
  end

  # The detail-style preview partial for a revision subject, or nil for subjects
  # that fall back to the plain field-by-field diff (Variant, Build, Catch…).
  def diff_preview_partial(record)
    case record
    when Lure then "lures/diff_preview"
    when Species then "species/diff_preview"
    when Brand then "brands/diff_preview"
    when Shop then "shops/diff_preview"
    end
  end

  # Whether a changeset touched a given field.
  def diff_changed?(changeset, field)
    changeset.present? && changeset.key?(field.to_s)
  end

  # Renders a record field inside a detail-style preview. When the field is part
  # of the changeset, the old value (red, struck through) and the new value
  # (green) are shown together so the change reads in context; otherwise the
  # record's current value is shown plainly. The optional block formats a raw
  # stored value (e.g. an id or enum) into display text.
  def diff_field(changeset, record, field, &block)
    fmt = ->(raw) { ((block ? block.call(raw) : raw).presence || t("common.none")).to_s }

    if diff_changed?(changeset, field)
      old_raw, new_raw = changeset[field.to_s]
      safe_join([
        tag.span(fmt.call(old_raw), class: "diff-old"),
        tag.span(fmt.call(new_raw), class: "diff-new")
      ])
    else
      fmt.call(record.public_send(field))
    end
  end

  # Resolve a changeset attachment value (a stored blob signed id) to its blob,
  # so a proposed photo can be previewed before it's applied. Returns nil for a
  # blank side or an id that no longer resolves (e.g. a purged blob).
  def diff_blob(signed_id)
    return nil if signed_id.blank?

    ActiveStorage::Blob.find_signed(signed_id)
  end

  # Changeset build_ids arrays are opaque in review — render build names
  # instead, falling back to the raw id for a since-deleted build. An empty
  # array is the open-world "unknown" state, shown as none.
  def diff_build_names(ids)
    ids = Array(ids)
    return t("common.none") if ids.empty?

    names = Build.where(id: ids).pluck(:id, :name).to_h
    ids.map { |id| names[id] || "##{id}" }.join(" · ")
  end

  # Display form of a stored diff value (raw attribute value from the changeset).
  def diff_value(value)
    case value
    when nil, ""
      t("common.none")
    when true then t("common.yes")
    when false then t("common.no")
    else value.to_s
    end
  end
end
