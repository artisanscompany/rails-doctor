# frozen_string_literal: true

module RailsDoctor
  module Reporters
    class Markdown
      attr_reader :project, :diagnostics, :score, :grade

      def initialize(project:, diagnostics:, score:, grade:, options: {})
        @project = project
        @diagnostics = diagnostics
        @score = score
        @grade = grade
      end

      def render(io = $stdout)
        io.puts header
        io.puts ""
        io.puts summary
        return io.puts "\nAll checks passed." if diagnostics.empty?

        diagnostics.group_by(&:category).sort_by { |c, ds| [-ds.size, c.to_s] }.each do |category, ds|
          io.puts ""
          io.puts "### #{category} (#{ds.size})"
          ds.group_by(&:rule_id).each do |rule_id, rule_ds|
            io.puts "- **#{rule_id}** (#{rule_ds.size}) — #{rule_ds.first.message}"
            rule_ds.first(5).each do |d|
              io.puts "  - `#{d.location}`" unless d.location.empty?
            end
            io.puts "  - … (+#{rule_ds.size - 5} more)" if rule_ds.size > 5
          end
        end
      end

      private

      def header
        info = project.to_h
        "## rails-doctor report\n\n" \
        "**Score: #{score}/100 — #{grade}**\n\n" \
        "Rails #{info[:rails_version] || '?'} · frontend: `#{info[:frontend]}` · jobs: `#{info[:jobs]}` · test: `#{info[:test]}` · assets: `#{info[:asset_pipeline]}`"
      end

      def summary
        counts = diagnostics.group_by(&:severity).transform_values(&:size)
        ["error", "warning", "info"].map { |s| "#{s}: #{counts[s.to_sym] || 0}" }.join(" · ")
      end
    end
  end
end
