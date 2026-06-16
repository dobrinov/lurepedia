module FlagsHelper
  FLAG_DIR = Rails.root.join("app/assets/images/flags")

  # Renders a circular flag. Uses the vendored circle-flags SVG when available,
  # falling back to the regional-indicator emoji.
  def country_flag(code, size: 20)
    code = code.to_s.downcase
    if flag_available?(code)
      image_tag("flags/#{code}.svg", alt: code.upcase, width: size, height: size, loading: "lazy",
                                     class: "flag", style: "border-radius:999px;display:block;flex-shrink:0;object-fit:cover")
    else
      tag.span(
        flag_emoji(code),
        class: "flag",
        title: code.upcase,
        style: "display:inline-flex;align-items:center;justify-content:center;" \
               "width:#{size}px;height:#{size}px;border-radius:999px;overflow:hidden;" \
               "background:#f4f4f5;font-size:#{(size * 0.95).round}px;line-height:1;flex-shrink:0"
      )
    end
  end

  def flag_available?(code)
    @flag_cache ||= {}
    @flag_cache[code] ||= File.exist?(FLAG_DIR.join("#{code.to_s.downcase}.svg")) ? :yes : :no
    @flag_cache[code] == :yes
  end

  def flag_emoji(code)
    code = code.to_s.upcase
    return "🏳️" unless code.match?(/\A[A-Z]{2}\z/)

    code.codepoints.map { |c| (c - 65 + 0x1F1E6) }.pack("U*")
  end
end
