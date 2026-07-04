# Analyze images with TileBackgroundAnalyzer (stock width/height analysis plus
# the border color used to paint letterboxed tiles). Active Storage runs only
# the FIRST analyzer that accepts a blob, so it goes in front of the built-in
# image analyzers.
#
# The engine copies this config list into ActiveStorage.analyzers during its
# own after_initialize, so mutating the config here (initializer time) is
# order-proof — registering a competing after_initialize hook is not. The
# class lives in lib/analyzers (exempt from autoloading) precisely so it can
# be required and referenced this early.
require Rails.root.join("lib/analyzers/tile_background_analyzer").to_s

Rails.application.config.active_storage.analyzers.prepend TileBackgroundAnalyzer
