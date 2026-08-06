# Search-engine visibility of our locales. `I18n.available_locales` is what a
# visitor can browse; `Locales.indexable` is the subset we publish to crawlers
# (sitemaps + hreflang), configured as `config.x.indexable_locales`.
#
# Everything outside the indexable set is served normally but marked noindex, so
# the near-duplicate translations don't compete with the English pages for crawl
# budget. Note this is deliberately *not* enforced in robots.txt: a disallowed
# page can't be crawled, so Google would never see the noindex and any already
# indexed URL would stay indexed.
module Locales
  def self.indexable
    Rails.application.config.x.indexable_locales
  end

  def self.indexable?(locale)
    indexable.include?(locale.to_s.to_sym)
  end
end
