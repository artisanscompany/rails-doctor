# frozen_string_literal: true

module RailsDoctor
  module Analyzers
    class Migrations < Base
      BOOLEAN_STATE_NAMES = %w[archived trashed favourited favorited closed accepted approved rejected completed cancelled canceled published pinned locked banned deleted].freeze

      NOUN_MAP = {
        "archived"   => "archive",
        "trashed"    => "trash",
        "favourited" => "favourite",
        "favorited"  => "favorite",
        "closed"     => "closure",
        "accepted"   => "acceptance",
        "approved"   => "approval",
        "rejected"   => "rejection",
        "completed"  => "completion",
        "cancelled"  => "cancellation",
        "canceled"   => "cancellation",
        "published"  => "publication",
        "pinned"     => "pin",
        "locked"     => "lock",
        "banned"     => "ban",
        "deleted"    => "deletion"
      }.freeze

      private

      def noun_for(col)
        NOUN_MAP[col] || col.sub(/ed$/, "").sub(/d$/, "")
      end

      def analyze(diagnostics)
        return unless project.has_dir?("db/migrate")

        pk_kinds = []

        Dir.glob(project.path("db/migrate/*.rb").to_s).each do |file|
          rel = relative(file)
          source = File.read(file)

          source.each_line.with_index(1) do |line, lineno|
            if (m = line.match(/t\.boolean\s+["':]([a-z_]+)["']?/))
              col = m[1]
              if BOOLEAN_STATE_NAMES.include?(col)
                emit(diagnostics, :"db/boolean-state-column",
                  message: "Boolean column `#{col}` encodes state as a flag.",
                  file: rel,
                  line: lineno
                )
              end
            end
          end

          source.scan(/^\s*add_reference\s+:\w+,\s+:(\w+),([^\n]*)$/).each do |(col, opts)|
            unless opts.include?("index:") || opts.include?("foreign_key: true")
              emit(diagnostics, :"db/missing-fk-index",
                message: "add_reference :#{col} without explicit index. Foreign keys should be indexed.",
                file: rel
              )
            end
          end

          # PK type tracking
          if source.match?(/id:\s*:uuid/) then pk_kinds << :uuid
          elsif source.match?(/create_table\b/) then pk_kinds << :bigint
          end

          # null: false without default — when adding a column to an existing
          # table, this fails on rows that already exist. We can only detect
          # this from the migration source. Skip create_table blocks (where
          # null: false is fine because the table is empty).
          source.scan(/^\s*add_column\s+:\w+,\s+:(\w+),\s+:(\w+)([^\n]*)$/).each do |col, type, opts|
            next unless opts.include?("null: false")
            next if opts.include?("default:")
            emit(diagnostics, :"migrations/null-false-without-default",
              message: "add_column :#{col} (#{type}) with `null: false` and no `default:`. This fails on existing rows.",
              file: rel
            )
          end

          # _id columns without foreign-key constraint (rough)
          source.scan(/t\.bigint\s+["']?(\w+)_id["']?/).each do |(name)|
            next if source.include?("foreign_key: { to_table:") || source.match?(/add_foreign_key\s+["']\S+["'],\s+["']?#{name}/)
            # only flag if the migration body has no add_foreign_key for this column
            unless source.match?(/add_foreign_key\b.*#{name}/)
              emit(diagnostics, :"db/foreign-key-without-constraint",
                message: "Column `#{name}_id` is declared as a plain bigint with no `foreign_key: true` or matching `add_foreign_key`. Add a DB-level constraint to prevent orphaned rows.",
                file: rel
              )
            end
          end
        end

        # Mixed PK types
        if pk_kinds.uniq.size > 1
          emit(diagnostics, :"db/inconsistent-pk-types",
            message: "Migrations mix UUID and integer primary keys. Pick one convention and stick to it.",
            file: "db/migrate"
          )
        end
      end
    end
  end
end
