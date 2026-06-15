module CatchesHelper
  def upvoted_label(catch)
    arrow = "▲"
    "#{arrow} #{catch.upvotes_count}"
  end
end
