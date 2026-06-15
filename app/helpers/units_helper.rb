module UnitsHelper
  def user_units_setting
    current_user&.units || "auto"
  end

  def fmt_length(cm)
    Units.format_length(cm, user_units_setting)
  end

  def fmt_weight(grams)
    Units.format_weight(grams, user_units_setting)
  end

  def fmt_depth(min_cm, max_cm)
    Units.format_depth(min_cm, max_cm, user_units_setting)
  end
end
