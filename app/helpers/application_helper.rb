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
    "CN" => "China", "BR" => "Brazil", "MX" => "Mexico", "FI" => "Finland",
    "AU" => "Australia", "NZ" => "New Zealand", "DK" => "Denmark", "IE" => "Ireland",
    "PT" => "Portugal", "KR" => "South Korea", "TH" => "Thailand", "ZA" => "South Africa",
    "IN" => "India", "AR" => "Argentina", "CL" => "Chile", "UA" => "Ukraine",
    "TR" => "Turkey", "AT" => "Austria", "BE" => "Belgium", "CH" => "Switzerland",
    "CZ" => "Czechia", "HU" => "Hungary", "RO" => "Romania"
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

  # Variant of a Croppable record's photo with the stored crop (if any)
  # applied before the requested transformations. `+repage` drops the virtual
  # canvas offset ImageMagick keeps after -crop.
  def cropped_photo(record, **transformations)
    if (geometry = record.photo_crop_geometry)
      record.photo.variant(crop: geometry, append: "+repage", **transformations)
    else
      record.photo.variant(**transformations)
    end
  end

  # The color to paint behind a letterboxed photo. Takes a Croppable record
  # (manual photo_bg_color override first, then the color measured by
  # TileBackgroundAnalyzer) or an attachment/bare blob (measured color only —
  # e.g. a diff preview of a proposed upload). Nil when nothing is known.
  def photo_background_color(source)
    return source.photo_background_color if source.respond_to?(:photo_background_color)
    return if source.respond_to?(:attached?) && !source.attached?

    (source.try(:blob) || source)&.metadata&.[]("background_color")
  end

  # Inline style painting a contain-fit tile with the photo's own border
  # color, so letterbox bars blend into the image. Blank (keep the default
  # tile background) when no color is known.
  def photo_frame_style(attachment)
    color = photo_background_color(attachment)
    "background:#{color}" if color
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
