module SeoHelper
  # Renders <link rel="alternate" hreflang="..."> for every locale + x-default,
  # all pointing at the current path with the locale swapped.
  def hreflang_tags
    safe_join(
      I18n.available_locales.map { |loc| alternate_tag(loc, loc.to_s) } +
        [alternate_tag(I18n.default_locale, "x-default")]
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
    @meta_description = value if value
    @meta_description.presence || t("home.meta_description")
  end

  private

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
