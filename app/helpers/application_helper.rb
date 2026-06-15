module ApplicationHelper
  # Native names for the language switcher (matches the prototype).
  LOCALE_NAMES = {
    en: { native: "English", country: "GB" },
    de: { native: "Deutsch", country: "DE" },
    fr: { native: "Français", country: "FR" },
    es: { native: "Español", country: "ES" },
    bg: { native: "Български", country: "BG" },
    el: { native: "Ελληνικά", country: "GR" },
    zh: { native: "中文", country: "CN" },
    ja: { native: "日本語", country: "JP" },
    ru: { native: "Русский", country: "RU" },
    nl: { native: "Nederlands", country: "NL" }
  }.freeze

  def available_locales_for_switcher
    I18n.available_locales.map { |l| [ l, LOCALE_NAMES.fetch(l, { native: l.to_s.upcase, country: "US" }) ] }
  end

  def locale_native(locale)
    LOCALE_NAMES.dig(locale.to_sym, :native) || locale.to_s.upcase
  end

  def locale_country(locale)
    LOCALE_NAMES.dig(locale.to_sym, :country) || "US"
  end

  COUNTRIES = {
    "US" => "United States", "CA" => "Canada", "GB" => "United Kingdom",
    "DE" => "Germany", "FR" => "France", "ES" => "Spain", "IT" => "Italy",
    "NL" => "Netherlands", "SE" => "Sweden", "NO" => "Norway", "PL" => "Poland",
    "RU" => "Russia", "BG" => "Bulgaria", "GR" => "Greece", "JP" => "Japan",
    "CN" => "China", "BR" => "Brazil", "MX" => "Mexico"
  }.freeze

  def country_options
    COUNTRIES.map { |code, name| [ "#{name}", code ] }
  end
end
