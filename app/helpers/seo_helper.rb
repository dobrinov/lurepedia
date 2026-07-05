module SeoHelper
  # og:locale wants language_TERRITORY; our locale codes are bare languages.
  OG_LOCALES = {
    bg: "bg_BG", de: "de_DE", el: "el_GR", en: "en_US", es: "es_ES",
    fr: "fr_FR", ja: "ja_JP", nl: "nl_NL", ru: "ru_RU", zh: "zh_CN"
  }.freeze

  DEFAULT_OG_IMAGE = "/android-chrome-512x512.png"

  # Renders <link rel="alternate" hreflang="..."> for every locale + x-default,
  # all pointing at the current path with the locale swapped.
  def hreflang_tags
    safe_join(
      I18n.available_locales.map { |loc| alternate_tag(loc, loc.to_s) } +
        [ alternate_tag(I18n.default_locale, "x-default") ]
    )
  end

  def canonical_tag
    tag.link(rel: "canonical", href: canonical_url)
  end

  def canonical_url
    url_for(only_path: false, locale: I18n.locale)
  rescue StandardError
    request.original_url
  end

  def page_title(value = nil)
    @page_title = value if value
    title = @page_title.presence || content_for(:title).presence
    base = "Lurepedia"
    title.present? ? "#{title} · #{base}" : "#{base} — #{t('home.tagline')}"
  end

  def meta_description(value = nil)
    @meta_description = value.to_s.squish.truncate(160) if value
    @meta_description.presence || t("home.meta_description")
  end

  # Social-share image for the current page. Views pass an attachment/variant
  # or URL; the reader side always returns an absolute URL (crawlers reject
  # relative og:image paths), falling back to the site icon.
  def meta_image(value = nil)
    @meta_image = value if value
    absolute_url(@meta_image.presence || DEFAULT_OG_IMAGE)
  end

  # Marks the current page as noindex (renders via robots_meta_tag).
  def noindex
    @noindex = true
    nil
  end

  def robots_meta_tag
    return unless @noindex

    tag.meta(name: "robots", content: "noindex,nofollow")
  end

  # The full Open Graph + Twitter card set, driven by the same values as the
  # title/description tags so shares always match the page.
  def open_graph_tags
    title = page_title
    description = meta_description
    image = meta_image

    safe_join([
      tag.meta(property: "og:site_name", content: "Lurepedia"),
      tag.meta(property: "og:type", content: "website"),
      tag.meta(property: "og:title", content: title),
      tag.meta(property: "og:description", content: description),
      tag.meta(property: "og:url", content: canonical_url),
      tag.meta(property: "og:image", content: image),
      tag.meta(property: "og:locale", content: OG_LOCALES.fetch(I18n.locale, I18n.locale.to_s)),
      *og_locale_alternates,
      tag.meta(name: "twitter:card", content: @meta_image.present? ? "summary_large_image" : "summary"),
      tag.meta(name: "twitter:title", content: title),
      tag.meta(name: "twitter:description", content: description),
      tag.meta(name: "twitter:image", content: image)
    ])
  end

  # Emits a schema.org JSON-LD block; nil values are pruned so callers can
  # pass optional fields unconditionally.
  def structured_data(data)
    payload = { "@context": "https://schema.org" }.merge(data).compact
    tag.script(payload.to_json.html_safe, type: "application/ld+json")
  end

  def absolute_url(source)
    url = source.is_a?(String) ? source : url_for(source)
    url.start_with?("http") ? url : "#{request.base_url}#{url}"
  rescue StandardError
    "#{request.base_url}#{DEFAULT_OG_IMAGE}"
  end

  private

  def og_locale_alternates
    (I18n.available_locales - [ I18n.locale ]).map do |loc|
      tag.meta(property: "og:locale:alternate", content: OG_LOCALES.fetch(loc, loc.to_s))
    end
  end

  def alternate_tag(locale, hreflang)
    href = begin
      url_for(only_path: false, locale: locale)
    rescue StandardError
      nil
    end
    return "".html_safe unless href

    tag.link(rel: "alternate", hreflang: hreflang, href: href)
  end
end
