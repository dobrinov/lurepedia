# PostgreSQL's `json` type has no equality operator, so any `SELECT DISTINCT`
# over a table carrying one fails outright:
#
#   PG::UndefinedFunction: could not identify an equality operator for type json
#
# LureFilter leans on DISTINCT (a lure matches when any of its builds does), so
# on SQLite — which has no such scruples — this was invisible, and on Postgres it
# takes out browse, search and every hub page. `jsonb` has the operator, and is
# the better choice anyway: it is indexable and stores parsed rather than
# re-parsing on every read.
#
# Defaults are dropped and restated around the cast, because ALTER TYPE will not
# carry a default across it.
class ConvertJsonColumnsToJsonb < ActiveRecord::Migration[8.1]
  # table => { column => default literal, or nil for a nullable column }
  COLUMNS = {
    "bans" => { "capabilities" => "'[]'" },
    "brands" => { "local_descriptions" => "'{}'" },
    "lures" => { "local_descriptions" => "'{}'" },
    "revisions" => { "changeset" => nil },
    "species" => { "local_descriptions" => "'{}'", "local_names" => "'{}'" }
  }.freeze

  def up
    change_all("jsonb")
  end

  def down
    change_all("json")
  end

  private

  def change_all(type)
    COLUMNS.each do |table, columns|
      columns.each do |column, default|
        execute "ALTER TABLE #{table} ALTER COLUMN #{column} DROP DEFAULT" if default
        execute "ALTER TABLE #{table} ALTER COLUMN #{column} TYPE #{type} USING #{column}::#{type}"
        execute "ALTER TABLE #{table} ALTER COLUMN #{column} SET DEFAULT #{default}::#{type}" if default
      end
    end
  end
end
