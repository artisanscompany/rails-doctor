# frozen_string_literal: true

module RailsDoctor
  module Analyzers
    # Hotwire conventions: Stimulus controller naming and Turbo frame id usage.
    class Hotwire < Base
      def analyze(diagnostics)
        return unless project.hotwire? || project.has_dir?("app/javascript/controllers")

        check_stimulus_controllers(diagnostics)
        check_turbo_frame_ids(diagnostics)
      end

      private

      def check_stimulus_controllers(diagnostics)
        # For every controller file foo_bar_controller.js → expect
        # `data-controller="foo-bar"` somewhere in app/views or app/components.
        dir = project.path("app/javascript/controllers")
        return unless dir.directory?

        controllers = Dir.glob(dir.join("**/*_controller.{js,ts}").to_s)
        return if controllers.empty?

        # Build a map of expected dasherized names from filenames.
        expected = controllers.map do |file|
          base = File.basename(file).sub(/_controller\.(?:js|ts)$/, "")
          dasherized = base.tr("_", "-")
          [dasherized, file]
        end.to_h

        # Scan views for `data-controller="…"` and `stimulus_controller("…")`.
        used = collect_used_controllers
        return if used.empty?

        used.each do |name, locations|
          next if expected.key?(name)
          next if name.include?(" ") # multi-controller string `data-controller="foo bar"` — handled below

          # Allow multi-controller strings: split & check each.
          parts = name.split
          missing = parts.reject { |p| expected.key?(p) }
          next if missing.empty?

          loc = locations.first
          missing.each do |m|
            emit(diagnostics, :"hotwire/stimulus-mismatched-controller",
              message: "data-controller=\"#{m}\" referenced but no #{m.tr('-', '_')}_controller.js exists.",
              file: loc[:file],
              line: loc[:line]
            )
          end
        end
      end

      def collect_used_controllers
        out = Hash.new { |h, k| h[k] = [] }
        return out unless project.has_dir?("app/views")
        Dir.glob(project.path("app/views/**/*.erb").to_s).each do |file|
          File.foreach(file).with_index(1) do |line, lineno|
            line.scan(/data-controller=["']([^"']+)["']/) do |match|
              out[match[0]] << { file: relative(file), line: lineno }
            end
          end
        end
        out
      end

      def check_turbo_frame_ids(diagnostics)
        return unless project.has_dir?("app/views")
        Dir.glob(project.path("app/views/**/*.erb").to_s).each do |file|
          File.foreach(file).with_index(1) do |line, lineno|
            # turbo_frame_tag "literal-string" — should be turbo_frame_tag(record)
            if line.match?(/turbo_frame_tag\s+["'][a-z][\w-]*["']/) && !line.include?("dom_id")
              emit(diagnostics, :"hotwire/turbo-frame-id-naming",
                message: "turbo_frame_tag uses a string literal id. Pass a record so `dom_id(record)` keeps the id in sync.",
                file: relative(file),
                line: lineno
              )
            end
          end
        end
      end
    end
  end
end
