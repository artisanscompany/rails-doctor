# frozen_string_literal: true

module RailsDoctor
  module Reporters
    class Json
      attr_reader :project, :diagnostics, :score, :grade

      def initialize(project:, diagnostics:, score:, grade:, options: {})
        @project = project
        @diagnostics = diagnostics
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
          diagnostics: diagnostics.map(&:to_h)
        }
      end

      def counts
        diagnostics.group_by(&:severity).transform_values(&:size)
      end
    end
  end
end
