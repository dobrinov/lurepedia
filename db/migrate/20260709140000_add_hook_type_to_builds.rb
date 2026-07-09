class AddHookTypeToBuilds < ActiveRecord::Migration[8.1]
  def change
    add_column :builds, :hook_type, :integer # nullable — nil means "unknown"
  end
end
