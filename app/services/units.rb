# Formats canonical measurements (lengths/depths in cm, weights in grams)
# into the user's preferred unit system. Each measurement type carries its own
# setting (:auto/:imperial/:metric); :auto is resolved from the viewer's country.
class Units
  CM_PER_IN = 2.54
  CM_PER_FT = 30.48
  G_PER_OZ = 28.3495
  G_PER_LB = 453.592

  # Countries that still use imperial measurements day to day.
  IMPERIAL_COUNTRIES = %w[ US LR MM ].freeze

  # Resolve :auto against the viewer's country (not their language).
  def self.system(setting, country: nil)
    setting = setting.to_s
    return setting.to_sym if %w[imperial metric].include?(setting)

    imperial_country?(country) ? :imperial : :metric
  end

  def self.imperial_country?(country)
    IMPERIAL_COUNTRIES.include?(country.to_s.upcase)
  end

  def self.format_length(cm, setting, country: nil)
    return nil if cm.blank?

    cm = cm.to_f
    if system(setting, country: country) == :imperial
      "#{round1(cm / CM_PER_IN)} #{I18n.t('units.in')}"
    else
      "#{round1(cm)} #{I18n.t('units.cm')}"
    end
  end

  def self.format_weight(grams, setting, country: nil)
    return nil if grams.blank?

    grams = grams.to_f
    if system(setting, country: country) == :imperial
      lb = grams / G_PER_LB
      if lb >= 1
        "#{round1(lb)} #{I18n.t('units.lb')}"
      else
        "#{round1(grams / G_PER_OZ)} #{I18n.t('units.oz')}"
      end
    elsif grams >= 1000
      "#{round1(grams / 1000)} #{I18n.t('units.kg')}"
    else
      "#{grams.round} #{I18n.t('units.g')}"
    end
  end

  def self.format_depth(min_cm, max_cm, setting, country: nil)
    return nil if min_cm.blank? && max_cm.blank?

    imperial = system(setting, country: country) == :imperial
    unit = imperial ? I18n.t("units.ft") : I18n.t("units.m")
    conv = ->(cm) { imperial ? round1(cm.to_f / CM_PER_FT) : round1(cm.to_f / 100) }

    if min_cm.present? && max_cm.present? && min_cm != max_cm
      "#{conv.call(min_cm)}–#{conv.call(max_cm)} #{unit}"
    else
      "#{conv.call(min_cm || max_cm)} #{unit}"
    end
  end

  def self.round1(value)
    rounded = value.round(1)
    rounded == rounded.to_i ? rounded.to_i : rounded
  end
end
