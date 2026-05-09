# frozen_string_literal: true

module RailsDoctor
  module Reporters
    class Json
      attr_reader :project, :result, :score, :grade

      def initialize(project:, result:, score:, grade:, options: {})
        @project = project
        @result = result
        @score = score
        @grade = grade
      end

      def render(io = $stdout)
        io.puts ::JSON.pretty_generate(payload)
      end

      private

      def payload
        {
          version: RailsDoctor::VERSION,
          project: project.to_h,
          score: score,
          grade: grade,
          counts: counts,
          stats: {
            total_findings: result.diagnostics.size,
            scanned_files: result.scanned_files,
            affected_files: result.diagnostics.map(&:file).compact.uniq.size,
            elapsed_ms: result.elapsed_ms,
            external_tools: result.external
          },
          diagnostics: result.diagnostics.map(&:to_h)
        }
      end

      def counts
        result.diagnostics.group_by(&:severity).transform_values(&:size)
      end
    end
  end
end
