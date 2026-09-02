# Copies the contents of the old SQLite production database into the current
# (PostgreSQL) one, table by table.
#
#   SNAPSHOT=/path/to/snap.sqlite3 bin/rails runner script/copy_sqlite_to_postgres.rb
#
# Take the snapshot with `VACUUM INTO` rather than copying the file: the live
# database keeps a write-ahead log that a plain copy would leave behind.
#
# Two conversions have to happen by hand, and both fail silently if you skip
# them. SQLite has no boolean type and stores 0/1, which PostgreSQL rejects
# outright for a boolean column. And a json column arrives as a *string* of
# JSON, which Active Record would helpfully encode a second time — leaving a
# document whose whole content is one escaped string. So each value is cast
# against the target column's type before it is handed over.
#
# Foreign keys are switched off for the session rather than worked around by
# ordering the tables, because the graph has a cycle: a lure points at its
# default variant and a variant points back at its lure. That needs superuser,
# which is why this runs against a local PostgreSQL and the result travels to
# the server as a pg_dump rather than being written there directly.
BATCH = 5_000

# Rails' own bookkeeping stays as the target created it, and the cache is
# throwaway state that would only arrive stale.
SKIP = %w[schema_migrations ar_internal_metadata solid_cache_entries].freeze

snapshot = ENV.fetch("SNAPSHOT")
abort "no such snapshot: #{snapshot}" unless File.exist?(snapshot)

target = ActiveRecord::Base.connection
abort "target is #{target.adapter_name}, expected PostgreSQL" unless target.adapter_name.match?(/postg/i)

class Source < ActiveRecord::Base
  self.abstract_class = true
end
Source.establish_connection(adapter: "sqlite3", database: snapshot, timeout: 5000)
source = Source.connection

source_tables = source.tables.to_set
target_tables = target.tables - SKIP

# A table on one side and not the other means the schemas have drifted, and
# copying regardless would quietly write a half-empty database.
missing = target_tables.reject { |t| source_tables.include?(t) }
extra = source_tables.to_a - target.tables
puts "source tables: #{source_tables.size}    target tables: #{target_tables.size}"
puts "!! in target but not in the snapshot: #{missing.join(', ')}" if missing.any?
puts "!! in the snapshot but not in target: #{extra.join(', ')}" if extra.any?
abort "schemas have drifted; not copying" if missing.any?

src_version = begin
  source.select_value("SELECT max(version) FROM schema_migrations")
rescue StandardError
  nil
end
puts "snapshot schema version: #{src_version}"
puts "target schema version:   #{target.select_value('SELECT max(version) FROM schema_migrations')}"
puts

copied = {}

target.transaction do
  target.execute "SET session_replication_role = replica"

  # One TRUNCATE for the lot, with CASCADE. Emptying them one at a time fails
  # even with the triggers off: refusing to truncate a table another one
  # references is a restriction of TRUNCATE itself, not a foreign-key trigger.
  puts "emptying #{target_tables.size} tables"
  target.execute "TRUNCATE TABLE #{target_tables.map { |t| target.quote_table_name(t) }.join(', ')} CASCADE"

  target_tables.each do |table|
    columns = target.columns(table).index_by(&:name)
    shared = source.columns(table).map(&:name) & columns.keys
    dropped = columns.keys - shared
    puts "  #{table}: only in target, left at its default: #{dropped.join(', ')}" if dropped.any?

    model = Class.new(ActiveRecord::Base) do
      self.table_name = table
      self.inheritance_column = nil
    end

    total = source.select_value("SELECT count(*) FROM #{source.quote_table_name(table)}").to_i
    quoted = shared.map { |c| source.quote_column_name(c) }.join(", ")
    offset = 0

    while offset < total
      rows = source.select_all(
        "SELECT #{quoted} FROM #{source.quote_table_name(table)} " \
        "ORDER BY rowid LIMIT #{BATCH} OFFSET #{offset}"
      ).to_a

      rows.each do |row|
        row.each do |name, value|
          next if value.nil?

          case columns[name].type
          when :boolean
            row[name] = ActiveModel::Type::Boolean.new.cast(value)
          when :json, :jsonb
            row[name] = value.is_a?(String) ? (JSON.parse(value) rescue value) : value
          end
        end
      end

      model.insert_all(rows, record_timestamps: false) if rows.any?

      offset += BATCH
    end

    copied[table] = target.select_value("SELECT count(*) FROM #{target.quote_table_name(table)}").to_i
    puts format("  %-42s %8d rows", table, copied[table])
  end

  target.execute "SET session_replication_role = DEFAULT"
end

# Rows arrived carrying their ids; the sequences behind them never moved, so
# without this the very next insert collides on the primary key.
puts "\nresetting sequences"
target_tables.each do |t|
  target.reset_pk_sequence!(t) if target.columns(t).any? { |c| c.name == "id" }
end

puts "\n--- source vs target ---"
mismatched = []
target_tables.sort.each do |table|
  src = source.select_value("SELECT count(*) FROM #{source.quote_table_name(table)}").to_i
  tgt = copied[table].to_i
  mismatched << table if src != tgt
  next if src.zero? && tgt.zero?

  puts format("%-42s %8d  %8d%s", table, src, tgt, src == tgt ? "" : "   <-- MISMATCH")
end

puts
abort "row counts differ for: #{mismatched.join(', ')}" if mismatched.any?
puts "every table matches."
