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
    # Display in the canonical order defined by LOCALE_NAMES, limited to enabled locales.
    available = I18n.available_locales
    LOCALE_NAMES.filter_map { |loc, meta| [ loc, meta ] if available.include?(loc) }
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
    COUNTRIES.keys.map { |code| [ country_name(code), code ] }.sort_by { |name, _| name }
  end

  # Translated country name for a code, falling back to the English name and
  # then the code itself.
  def country_name(code)
    code = code.to_s.upcase
    I18n.t("country.#{code}", default: COUNTRIES[code] || code)
  end

  # Inner content for an `.avatar` element: the user's uploaded picture when
  # present, otherwise their initials. Wrap the result in a `.avatar` span or
  # button at the call site. `size` is the rendered px size (a 2x variant is
  # requested for crisp display on retina screens).
  def user_avatar(user, size: 34)
    if user.respond_to?(:avatar) && user.avatar.attached? && user.avatar.variable?
      image_tag user.avatar.variant(resize_to_fill: [ size * 2, size * 2 ]),
                alt: user.name, loading: "lazy"
    else
      user.try(:initials).presence || "?"
    end
  end

  # Small "opens in a new tab" glyph appended to external links.
  def external_link_icon(size: 12)
    raw(
      %(<svg width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" ) +
      %(stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" ) +
      %(style="display:inline-block;vertical-align:-1px;margin-left:3px;opacity:.55;flex-shrink:0">) +
      %(<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path>) +
      %(<polyline points="15 3 21 3 21 9"></polyline><line x1="10" y1="14" x2="21" y2="3"></line></svg>)
    )
  end
end
