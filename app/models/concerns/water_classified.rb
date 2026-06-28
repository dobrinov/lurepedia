# Shared { fresh, salt, both } water-type enum, used by any catalog record that
# classifies a lure or species by the water it suits. The column name varies
# (e.g. LureType stores it as water_default), so it is passed in.
module WaterClassified
  extend ActiveSupport::Concern

  class_methods do
    def water_enum(column = :water)
      enum column, { fresh: 0, salt: 1, both: 2 }, prefix: :water
    end
  end
end
