# frozen_string_literal: true

require_relative "../ast"

module RailsDoctor
  module Analyzers
    class Models < Base
      GENERIC_NAMES = %w[helpers methods utils mixin shared common stuff base validations callbacks].freeze
      CALLBACK_MACROS = %i[
        before_validation after_validation
        before_save after_save around_save
        before_create after_create around_create
        before_update after_update around_update
        before_destroy after_destroy around_destroy
        after_commit after_create_commit after_update_commit after_destroy_commit after_save_commit
        after_initialize after_find after_touch
      ].freeze

      private

      def analyze(diagnostics)
        return unless project.has_dir?("app/models")

        # Concerns: top-level files in app/models/concerns AND model-namespaced
        # files like app/models/<model>/<trait>.rb.
        concern_files = Dir.glob(project.path("app/models/concerns/**/*.rb").to_s) +
                        model_namespaced_files

        concern_files.uniq.each { |f| check_concern(diagnostics, f) }

        Dir.glob(project.path("app/models/*.rb").to_s).each { |f| check_model(diagnostics, f) }
      end

      def model_namespaced_files
        Dir.glob(project.path("app/models/*/*.rb").to_s).reject do |f|
          # Skip the file matching the directory name (the parent class)
          File.basename(f) == "#{File.basename(File.dirname(f))}.rb"
        end
      end

      def check_concern(diagnostics, file)
        rel = relative(file)
        name = File.basename(file, ".rb")
        loc = file_loc(file)

        if loc > threshold("concern_max_loc")
          emit(diagnostics, :"models/concern-too-large",
            message: "Concern #{name} is #{loc} LOC (threshold #{threshold('concern_max_loc')}). 37signals: a concern names a single trait — split it or fold it back into the model.",
            file: rel
          )
        end

        if loc < threshold("concern_min_loc") && loc.positive?
          emit(diagnostics, :"models/concern-too-small",
            message: "Concern #{name} is #{loc} LOC. Premature abstraction — inline it back into the model.",
            file: rel
          )
        end

        if GENERIC_NAMES.include?(name.downcase)
          emit(diagnostics, :"models/concern-bad-name",
            message: "Concern #{name} has a generic name. A concern should name a trait or capability (e.g. Searchable, Bannable, Mentionable).",
            file: rel
          )
        end
      end

      def check_model(diagnostics, file)
        rel = relative(file)
        return if file.end_with?("application_record.rb")

        tree = AST.parse_file(file)
        klass = AST.primary_class(tree)
        loc = file_loc(file)

        if loc > threshold("model_max_loc")
          emit(diagnostics, :"models/fat-model",
            message: "Model #{model_name(file)} is #{loc} LOC. Consider extracting per-model concerns (`app/models/<model>/<trait>.rb`).",
            file: rel
          )
        end

        return unless klass

        # Anemic detection. AST-based; skip when concerns are included.
        if loc >= 30 && !AST.includes_concern?(klass)
          instance_defs = AST.all_def_nodes(klass).reject(&:receiver).size
          if instance_defs.zero?
            assoc_count = %i[has_many has_one belongs_to has_and_belongs_to_many].sum { |m| AST.macro_count(klass, m) }
            valid_count = AST.macro_count(klass, :validates) + AST.macro_count(klass, :validate)
            if assoc_count + valid_count >= 6
              emit(diagnostics, :"models/anemic-model",
                message: "Model #{model_name(file)} has #{assoc_count} associations and #{valid_count} validations but zero instance methods and no included concerns. Active Record models are designed to hold domain behavior — keep persistence and logic together.",
                file: rel
              )
            end
          end
        end

        # Callback overuse
        callback_total = CALLBACK_MACROS.sum { |m| AST.macro_count(klass, m) }
        if callback_total > 5
          emit(diagnostics, :"models/callback-overuse",
            message: "Model #{model_name(file)} declares #{callback_total} callbacks. 37signals defends callbacks for orthogonal/auxiliary concerns, but heavy callback chains suggest the work belongs in named methods or extracted concerns.",
            file: rel
          )
        end

        # Uniqueness validation without DB-level unique index. Only emit when
        # we can locate the model's create_table block in schema.rb AND it
        # contains no unique index. Otherwise stay quiet (the schema may live
        # in a structure.sql file or earlier migration we can't easily map).
        source = File.read(file)
        if (m = source.match(/validates\s+:(\w+).*uniqueness/m)) && schema_lacks_unique_for?(file, m[1])
          col = m[1]
          emit(diagnostics, :"models/uniqueness-without-index",
            message: "Model #{model_name(file)} validates uniqueness of `#{col}` but the schema's create_table block has no unique index on it. Add `add_index :<table>, :#{col}, unique: true` to prevent races.",
            file: rel
          )
        end

        # Pluck-over-map heuristic
        if (m = source.match(/\.map\s*\(\s*&:(\w+)\s*\)/))
          attr = m[1]
          emit(diagnostics, :"performance/pluck-over-map",
            message: "Found `.map(&:#{attr})`. If this targets an Active Record relation, use `.pluck(:#{attr})` to avoid instantiating records.",
            file: rel
          )
        end
      end

      def schema_lacks_unique_for?(file, column)
        schema = project.path("db/schema.rb")
        return false unless schema.exist?
        text = schema.read
        table = File.basename(file, ".rb").pluralize_simple
        block = text[/create_table\s+["']#{table}["'].*?\bend/m]
        return false unless block
        # Look for either an inline `t.index :col, unique: true` or a separate
        # `add_index "table", :col, unique: true` somewhere in the schema.
        return false if block.match?(/t\.index\s+\[?["':]?#{column}["']?\]?.*unique:\s*true/m)
        return false if text.match?(/add_index\s+["']#{table}["'],\s*\[?["':]?#{column}["']?\]?.*unique:\s*true/m)
        true
      end

      def model_name(file)
        File.basename(file, ".rb").split("_").map(&:capitalize).join
      end
    end
  end
end

# Vendored tiny pluralize so we don't pull in active_support.
class String
  def pluralize_simple
    case self
    when /(?:s|x|z|ch|sh)$/ then "#{self}es"
    when /[^aeiou]y$/      then sub(/y$/, "ies")
    else "#{self}s"
    end
  end
end
