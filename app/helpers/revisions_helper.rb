module RevisionsHelper
  # Human label for a changed attribute, e.g. "depth_min_cm" -> "Depth min (cm)".
  def diff_field_label(field)
    key = field.to_s
    return t("revision.field.#{key}") if I18n.exists?("revision.field.#{key}")

    key.sub(/_id\z/, "").sub(/_cm\z/, " (cm)").sub(/_g\z/, " (g)").humanize
  end

  # Path to the record a revision belongs to (nil for subjects with no show page).
  def revision_subject_path(subject)
    case subject
    when Lure then lure_path(subject)
    when Brand then brand_path(subject)
    when Species then species_path(subject)
    when Catch then catch_path(subject)
    end
  end

  # Human label for a revision's subject record.
  def revision_subject_label(subject)
    case subject
    when Lure then subject.title
    when Brand, Shop then subject.name
    when Species then subject.common_name
    else subject.class.name
    end
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
