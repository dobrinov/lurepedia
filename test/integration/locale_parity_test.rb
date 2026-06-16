require "test_helper"

# The app actively maintains translations for these locales; the remaining
# available locales are intentional stubs that fall back to English
# (config.i18n.fallbacks = [:en]). This test guards that the maintained
# locales stay in full key-parity with the English source.
class LocaleParityTest < ActiveSupport::TestCase
  MAINTAINED_LOCALES = %w[de bg ja].freeze

  EN = YAML.load_file(Rails.root.join("config/locales/en.yml"))["en"]

  def flatten_keys(hash, prefix = "")
    hash.flat_map do |k, v|
      key = prefix.empty? ? k.to_s : "#{prefix}.#{k}"
      v.is_a?(Hash) ? flatten_keys(v, key) : [ key ]
    end
  end

  MAINTAINED_LOCALES.each do |locale|
    test "#{locale} has every English key" do
      data = YAML.load_file(Rails.root.join("config/locales/#{locale}.yml"))[locale] || {}
      missing = flatten_keys(EN) - flatten_keys(data)
      assert_empty missing, "#{locale}.yml is missing keys: #{missing.join(', ')}"
    end
  end
end
