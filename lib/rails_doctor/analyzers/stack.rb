# frozen_string_literal: true

module RailsDoctor
  module Analyzers
    class Stack < Base
      private

      def analyze(diagnostics)
        if project.sprockets? && project.propshaft?
          emit(diagnostics, :"stack/sprockets-and-propshaft",
            message: "Both `sprockets-rails` and `propshaft` are installed. Pick one — Propshaft is the Rails 8 default.",
            file: "Gemfile"
          )
        end

        if project.solid_queue? && !project.has_gem?("mission_control-jobs")
          emit(diagnostics, :"stack/missing-mission-control",
            message: "Solid Queue is installed but `mission_control-jobs` is not. Mounting it gives you a web UI for jobs.",
            file: "Gemfile"
          )
        end

        if project.has_file?("bin/importmap") && !project.has_file?("config/importmap.rb")
          emit(diagnostics, :"stack/vestigial-importmap",
            message: "bin/importmap exists but config/importmap.rb does not. Looks like an importmap-rails leftover from a previous stack — remove the binstub.",
            file: "bin/importmap"
          )
        end

        if project.has_gem?("redis") && project.solid_cache?
          emit(diagnostics, :"stack/redis-with-solid-cache",
            message: "Redis is in the Gemfile alongside solid_cache. If Redis is only used for cache/cable, you can remove it; keep it only for typed Kredis structures or Action Cable.",
            file: "Gemfile"
          )
        end

        if project.has_gem?("devise") && uses_has_secure_password?
          emit(diagnostics, :"stack/devise-and-has-secure-password",
            message: "Devise is in the Gemfile but the project also calls `has_secure_password`. Pick one — Rails 8's built-in auth covers most cases.",
            file: "Gemfile"
          )
        end

        check_sti_indexes(diagnostics)
      end

      def uses_has_secure_password?
        Dir.glob(project.path("app/models/**/*.rb").to_s).any? do |f|
          File.read(f).include?("has_secure_password")
        end
      end

      def check_sti_indexes(diagnostics)
        schema = project.path("db/schema.rb")
        return unless schema.exist?
        text = schema.read
        # Look for create_table blocks that include t.string "type" and check for an index on type.
        text.scan(/create_table\s+["'](\w+)["'].*?\bend\b/m).each do |(table)|
          block = text[/create_table\s+["']#{table}["'].*?\bend/m] || ""
          next unless block.match?(/t\.string\s+["']type["']/)
          next if block.match?(/t\.index\s+\[?["']type["']/) || block.match?(/index:\s*true/)
          emit(diagnostics, :"stack/sti-without-type-index",
            message: "Table `#{table}` has a `type` column (STI) but no index on it. Add `t.index :type` for query performance.",
            file: "db/schema.rb"
          )
        end
      end
    end
  end
end
