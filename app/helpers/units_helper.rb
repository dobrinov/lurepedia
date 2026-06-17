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

  private

  def user_units_setting(measurement)
    current_user&.public_send("#{measurement}_units") || "auto"
  end

  # Registered users carry an explicit country; for anonymous visitors we fall
  # back to the country implied by the active locale.
  def viewer_country
    current_user&.country || locale_country(I18n.locale)
  end
end
