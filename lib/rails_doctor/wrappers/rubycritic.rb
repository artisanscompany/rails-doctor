# frozen_string_literal: true

module RailsDoctor
  module Wrappers
    class Rubycritic < Base
      BINARY = "rubycritic"
      GEM = "rubycritic"

      private

      def run
        diagnostics = []
        # JSON output goes to tmp/rubycritic/report.json by default
        run_cmd(["rubycritic", "--mode-ci", "--no-browser", "-f", "json", "app", "lib"])

        report_path = project.path("tmp/rubycritic/report.json")
        return diagnostics unless report_path.exist?

        data = JSON.parse(report_path.read) rescue nil
        return diagnostics unless data.is_a?(Hash)

        Array(data["analysed_modules"]).each do |mod|
          rating = mod["rating"]
          next unless %w[D F].include?(rating)
          emit(diagnostics, :"smells/reek",
            message: "RubyCritic rates this module #{rating} (cost #{mod['cost']}, churn #{mod['churn']}).",
            file: mod["path"]
          )
        end
        diagnostics
      end
    end
  end
end
