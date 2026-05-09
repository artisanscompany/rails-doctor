# frozen_string_literal: true

module RailsDoctor
  module Analyzers
    # Rails-side Inertia conventions. Complements design-doctor's React-side
    # Inertia rules (Link vs <a>, useForm, page-component-naming).
    class Inertia < Base
      def analyze(diagnostics)
        return unless project.inertia?

        check_shared_props(diagnostics)
        scan_controllers(diagnostics)
      end

      private

      # `inertia_share` blocks run on every request. If they call expensive
      # methods (current_user.something_with_n_plus_one, .count, .where) we
      # warn so the team can move that into per-page props.
      def check_shared_props(diagnostics)
        candidates = [
          project.path("app/controllers/application_controller.rb"),
          *Dir.glob(project.path("app/controllers/concerns/*.rb").to_s).map { |p| Pathname.new(p) },
        ]
        candidates.each do |path|
          next unless path.exist?
          src = path.read
          src.scan(/inertia_share\s+do\b(.+?)\bend\b/m).each do |match|
            block = match.is_a?(Array) ? match.first : match
            heavy = block.scan(/\.(?:where|joins|includes|count|sum|map|find_each|all)\b/).size
            next if heavy.zero?
            emit(diagnostics, :"inertia/heavy-shared-props",
              message: "inertia_share block performs database work (#{heavy} chained call#{heavy == 1 ? '' : 's'}). Runs on every request; move per-page data into render props.",
              file: relative(path.to_s)
            )
          end
        end
      end

      def scan_controllers(diagnostics)
        Dir.glob(project.path("app/controllers/**/*.rb").to_s).each do |file|
          next if file.end_with?("application_controller.rb")
          src = File.read(file)
          rel = relative(file)

          # render inertia: "Foo" without an explicit `props:` key. The
          # render still works (Inertia falls back to controller instance
          # variables), but explicit props keep the contract obvious.
          src.scan(/^\s*render\s+inertia:\s*["']([^"']+)["']([^\n]*)$/).each do |page, rest|
            next if rest.include?("props:")
            next if rest.include?(",") && rest.match?(/:\s*\w+/) # already passing keyword args
            emit(diagnostics, :"inertia/render-without-props",
              message: "render inertia: \"#{page}\" without an explicit `props:` hash.",
              file: rel
            )
          end

          # (instance-var-not-passed dropped: too lossy across CRUD helper
          # concerns, before_action setters, and props-method indirection. We'd
          # need real call-graph analysis to be precise.)
        end
      end
    end
  end
end
