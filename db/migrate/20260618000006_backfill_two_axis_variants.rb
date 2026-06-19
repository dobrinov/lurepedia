class BackfillTwoAxisVariants < ActiveRecord::Migration[8.1]
  # Lightweight, schema-agnostic models so this migration keeps working even as
  # the application models evolve away from the pre-migration column layout.
  class MigrationLure < ActiveRecord::Base
    self.table_name = "lures"
  end

  class MigrationVariant < ActiveRecord::Base
    self.table_name = "variants"
  end

  class MigrationBuild < ActiveRecord::Base
    self.table_name = "builds"
  end

  class MigrationVariantBuild < ActiveRecord::Base
    self.table_name = "variant_builds"
  end

  class MigrationCatch < ActiveRecord::Base
    self.table_name = "catches"
  end

  def up
    MigrationLure.reset_column_information
    MigrationVariant.reset_column_information

    MigrationLure.find_each do |lure|
      variants = MigrationVariant.where(lure_id: lure.id).order(:id).to_a
      rep = variants.first

      build = MigrationBuild.create!(
        lure_id: lure.id,
        name: "Standard",
        length_mm: rep&.size_mm,
        weight_g: rep&.weight_g,
        depth_min_cm: lure.depth_min_cm,
        depth_max_cm: lure.depth_max_cm,
        action: lure.action || 0,
        position: 0
      )

      variants.each do |variant|
        MigrationVariantBuild.create!(variant_id: variant.id, build_id: build.id)
        MigrationCatch.where(variant_id: variant.id).update_all(build_id: build.id)
      end

      MigrationBuild.where(id: build.id)
        .update_all(catches_count: MigrationCatch.where(build_id: build.id).count)

      lure.update_columns(default_variant_id: rep&.id) if rep
    end
  end

  def down
    MigrationVariantBuild.delete_all
    MigrationBuild.delete_all
    MigrationCatch.update_all(build_id: nil)
    MigrationLure.update_all(default_variant_id: nil)
  end
end
