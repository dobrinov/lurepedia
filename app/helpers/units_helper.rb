module UnitsHelper
  def fmt_length(cm)
    Units.format_length(cm, user_units_setting(:length), country: viewer_country)
  end

  def fmt_weight(grams)
    Units.format_weight(grams, user_units_setting(:weight), country: viewer_country)
  end

  def fmt_depth(min_cm, max_cm)
    Units.format_depth(min_cm, max_cm, user_units_setting(:depth), country: viewer_country)
  end

  # Lure body size is conventionally quoted in millimetres (the "110" in a
  # "110mm jerkbait"); shown as-is rather than converted like fish lengths.
  def fmt_size_mm(mm)
    mm.present? ? "#{mm} mm" : nil
  end

  # The unit the viewer thinks in when typing a lure weight (search filters).
  def viewer_weight_unit
    Units.system(user_units_setting(:weight), country: viewer_country) == :imperial ? "oz" : "g"
  end

  # Registered users carry an explicit country; for anonymous visitors we fall
  # back to the country implied by the active locale.
  def viewer_country
    current_user&.country || locale_country(I18n.locale)
  end

  private

  def user_units_setting(measurement)
    current_user&.public_send("#{measurement}_units") || "auto"
  end
end
