module LuresHelper
  # Reserved trailing segments that mean "tab", so a color by that name can't be
  # mistaken for one.
  LURE_TABS = %w[caught buy history variations].freeze

  # Build a lure URL for a given tab and (optional) color. The default
  # "variations" tab is implicit, so a color on it reads /lures/<slug>/<color>;
  # other tabs carry their name: /lures/<slug>/<tab>/<color>.
  def lure_tab_path(lure, tab:, color: nil)
    if color.blank?
      tab == "variations" ? lure_path(lure) : lure_path(lure, tab: tab)
    elsif tab == "variations" && LURE_TABS.exclude?(color)
      lure_color_path(lure, color)
    else
      lure_path(lure, tab: tab, color: color)
    end
  end

  # Resolve the photo to show for a catch: its own snapshot first, else the
  # caught-on color's photo — "show the variation whenever possible".
  def catch_display_photo(catch)
    return catch.photos.first if catch.photos.attached?
    return catch.variant.photo if catch.variant&.photo&.attached?

    nil
  end
end
