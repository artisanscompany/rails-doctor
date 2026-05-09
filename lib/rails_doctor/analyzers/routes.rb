# frozen_string_literal: true

module RailsDoctor
  module Analyzers
    class Routes < Base
      VERB_KEYWORDS = %w[approve publish archive trash unarchive untrash favourite favorite pin unpin lock unlock close open accept reject submit cancel complete refund toggle bulk import export].freeze

      private

      def analyze(diagnostics)
        path = project.path("config/routes.rb")
        return unless path.exist?

        text = path.read
        text.each_line.with_index(1) do |line, lineno|
          stripped = line.strip
          next if stripped.start_with?("#")

          if stripped.match?(/\b(member|collection)\s+do\b/)
            emit(diagnostics, :"routes/non-restful",
              message: "`#{stripped[/\b(member|collection)\s+do\b/]}` block. Prefer extracting to a noun resource (e.g. `resource :archive, only: %i[create destroy]`).",
              file: "config/routes.rb",
              line: lineno
            )
          end

          # Custom verb routes: get "/posts/:id/publish", to: "posts#publish"
          if (m = stripped.match(/^\s*(get|post|put|patch|delete)\s+["']([^"']+)["'].*?(?:to:\s*["'][^#]+#(\w+)["'])?/))
            verb_method, route_path, action = m.captures
            next if route_path.start_with?("/up", "/health", "/rails", "/sitemap", "/webhooks", "/_")
            verb_in_path = (route_path.split("/") + [action].compact).any? { |seg| VERB_KEYWORDS.include?(seg.to_s.downcase) }
            if verb_in_path
              emit(diagnostics, :"routes/verbs-not-nouns",
                message: "Custom verb route detected.",
                file: "config/routes.rb",
                line: lineno
              )
            end
          end
        end
      end
    end
  end
end
