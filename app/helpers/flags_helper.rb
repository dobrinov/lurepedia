module FlagsHelper
  # Renders a circular flag using the regional-indicator emoji for the country code.
  def country_flag(code, size: 20)
    code = code.to_s.upcase
    emoji = flag_emoji(code)
    tag.span(
      emoji,
      class: "flag",
      title: code,
      style: "display:inline-flex;align-items:center;justify-content:center;" \
             "width:#{size}px;height:#{size}px;border-radius:999px;overflow:hidden;" \
             "background:#f4f4f5;font-size:#{(size * 0.95).round}px;line-height:1;flex-shrink:0"
    )
  end

  def flag_emoji(code)
    code = code.to_s.upcase
    return "🏳️" unless code.match?(/\A[A-Z]{2}\z/)

    code.codepoints.map { |c| (c - 65 + 0x1F1E6) }.pack("U*")
  end
end
