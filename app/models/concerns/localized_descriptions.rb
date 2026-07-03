# Contributor-supplied descriptions stored per locale in a
# `local_descriptions` JSON column. Assignment compacts blank values so an
# empty form field never shadows a fallback; #description resolves the
# viewer's locale, then English, then nothing.
module LocalizedDescriptions
  extend ActiveSupport::Concern

  def local_descriptions=(value)
    super((value || {}).to_h.transform_values { |v| v.to_s.strip }.reject { |_, v| v.blank? })
  end

  def description
    descriptions = local_descriptions || {}
    descriptions[I18n.locale.to_s].presence || descriptions["en"].presence
  end
end
