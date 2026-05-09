# frozen_string_literal: true

module RailsDoctor
  module Reporters
    class Tty
      COLORS = {
        red: 31, yellow: 33, green: 32, cyan: 36, gray: 90, bold: 1, reset: 0
      }.freeze

      SEVERITY_COLOR = { error: :red, warning: :yellow, info: :cyan }.freeze

      attr_reader :project, :diagnostics, :score, :grade, :options

      def initialize(project:, diagnostics:, score:, grade:, options: {})
        @project = project
        @diagnostics = diagnostics
        @score = score
        @grade = grade
        @options = options
      end

      def render(io = $stdout)
        @io = io
        header
        summary
        if diagnostics.empty?
          puts color("All checks passed.", :green)
          return
        end
        groups
        footer
      end

      private

      def color(str, *codes)
        return str if options[:no_color] || !$stdout.tty?
        prefix = codes.map { |c| "\e[#{COLORS[c]}m" }.join
        "#{prefix}#{str}\e[0m"
      end

      def puts(*args)
        @io.puts(*args)
      end

      def header
        puts color("rails-doctor #{RailsDoctor::VERSION}", :bold)
        puts color("project: #{project.root}", :gray)
        info = project.to_h
        puts color("rails: #{info[:rails_version] || '?'}  frontend: #{info[:frontend]}  jobs: #{info[:jobs]}  test: #{info[:test]}  assets: #{info[:asset_pipeline]}", :gray)
        puts
      end

      def summary
        score_color = score >= 75 ? :green : (score >= 50 ? :yellow : :red)
        puts "#{color('Health score:', :bold)} #{color("#{score}/100", score_color, :bold)}  (#{grade})"

        counts = diagnostics.group_by(&:severity).transform_values(&:size)
        line = SEVERITIES.map { |s| "#{color(s.to_s, SEVERITY_COLOR[s])}: #{counts[s] || 0}" }.join("  ")
        puts line
        puts
      end

      def groups
        diagnostics.group_by(&:category).sort_by { |c, ds| [-ds.size, c.to_s] }.each do |category, ds|
          puts color("[#{category}] #{ds.size} finding#{ds.size == 1 ? '' : 's'}", :bold)
          ds.group_by(&:rule_id).each do |rule_id, rule_ds|
            count = rule_ds.size
            sample = rule_ds.first
            puts "  #{color(sev_label(sample.severity), SEVERITY_COLOR[sample.severity])} #{rule_id} (#{count})"
            puts "    #{color(sample.message, :gray)}"
            rule_ds.first(3).each do |d|
              loc = d.location
              puts "    - #{loc}" unless loc.empty?
            end
            extra = count - 3
            puts color("    (+#{extra} more)", :gray) if extra.positive?
          end
          puts
        end
      end

      def footer
        puts color("Run with --json for machine-readable output, or --explain <rule-id> for details.", :gray)
      end

      def sev_label(severity)
        case severity
        when :error then "ERR"
        when :warning then "WRN"
        when :info then "INF"
        else "---"
        end
      end
    end
  end
end
