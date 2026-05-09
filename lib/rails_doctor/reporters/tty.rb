# frozen_string_literal: true

module RailsDoctor
  module Reporters
    # TTY output structured to mirror react-doctor:
    #   1. Header line (rails-doctor vX.Y.Z)
    #   2. Detection phase  (✔ Detecting framework, version, etc.)
    #   3. Analysis phase   (✔ Running architecture / model / ... checks.)
    #   4. Findings, grouped by category, capped in non-verbose mode
    #   5. Score block (face + bar + branding)
    #   6. Footer  (N issues across A/T files in Nms)
    class Tty
      MAX_CATEGORIES_NON_VERBOSE = 5
      MAX_RULES_PER_CATEGORY_NON_VERBOSE = 3
      RULE_NAME_COLUMN_WIDTH = 36
      WRAP_WIDTH = 88
      BRANDING = "Rails Doctor (github.com/artisanscompany/rails-doctor)"

      COLORS = { red: 31, yellow: 33, green: 32, cyan: 36, gray: 90, bold: 1, dim: 2 }.freeze
      SEVERITY_SYMBOLS = { error: "✗", warning: "⚠", info: "ℹ" }.freeze
      SEVERITY_COLORS  = { error: :red, warning: :yellow, info: :cyan }.freeze

      attr_reader :project, :result, :score, :grade, :options

      def initialize(project:, result:, score:, grade:, options: {})
        @project = project
        @result = result
        @score = score
        @grade = grade
        @options = options
      end

      def render(io = $stdout)
        @io = io
        header
        detection
        analysis
        if result.diagnostics.empty?
          puts color("All checks passed.", :green)
        else
          findings
        end
        score_block
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
        puts "rails-doctor v#{RailsDoctor::VERSION}"
        puts ""
      end

      def detection
        info = project.to_h
        emit_step("Detecting Rails. Found Rails #{info[:rails_version] || '(unknown)'}.")
        emit_step("Detecting frontend. Found #{info[:frontend]}.")
        emit_step("Detecting test framework. Found #{info[:test]}.")
        emit_step("Detecting jobs adapter. Found #{info[:jobs]}.")
        emit_step("Detecting asset pipeline. Found #{info[:asset_pipeline]}.")
        emit_step("Found #{result.scanned_files} source files.")
        if %w[inertia spa-react-vue].include?(info[:frontend])
          emit_step("Companion: design-doctor (run `npx -y design-doctor scan .` for the React side).")
        end
        puts ""
      end

      def analysis
        result.analyzers.each { |label| emit_step("Running #{label} checks.") }
        unless result.external.empty?
          emit_step("Running external tools: #{result.external.join(', ')}.")
        end
        puts ""
      end

      def emit_step(text)
        check = color("✔", :green)
        puts "#{check} #{text}"
      end

      def findings
        category_groups = build_category_groups(result.diagnostics)
        verbose = options[:verbose] || options[:full]
        visible = verbose ? category_groups : category_groups.first(MAX_CATEGORIES_NON_VERBOSE)
        hidden_categories = verbose ? [] : category_groups.drop(MAX_CATEGORIES_NON_VERBOSE)
        hidden_rule_count = hidden_categories.sum { |_, rules| rules.size }

        visible.each do |category, rule_groups|
          visible_rules = verbose ? rule_groups : rule_groups.first(MAX_RULES_PER_CATEGORY_NON_VERBOSE)
          remaining = verbose ? [] : rule_groups.drop(MAX_RULES_PER_CATEGORY_NON_VERBOSE)
          hidden_rule_count += remaining.size

          puts "#{color(category.to_s.tr('_', ' ').capitalize, :bold)} #{color("#{rule_groups.sum { |_, ds| ds.size }} issues", :gray)}"
          visible_rules.each { |(rule_id, diagnostics)| print_rule_group(rule_id, diagnostics) }
          puts ""
        end

        if hidden_rule_count.positive?
          puts color("  ⚠ #{hidden_rule_count} more rule#{hidden_rule_count == 1 ? '' : 's'}", :gray)
          puts color("    Run `npx -y rails-doctor@latest scan . --verbose` to get all details", :dim)
          puts ""
        end
      end

      def print_rule_group(rule_id, diagnostics)
        sample = diagnostics.first
        symbol = color(SEVERITY_SYMBOLS[sample.severity] || "·", SEVERITY_COLORS[sample.severity])
        title = humanize(rule_id)
        count_label = "×#{diagnostics.size}"
        puts "  #{symbol} #{title} #{color(count_label, :dim)}"
        puts indent(wrap(sample.message), 4)
        puts indent(wrap(sample.fix), 4) if sample.fix && sample.fix != sample.message
        puts indent(sample.location, 4) unless sample.location.empty?
      end

      def build_category_groups(diagnostics)
        # Group by category, then by rule_id within each category.
        # Sort categories by total finding count (desc); rules within by count (desc).
        by_category = diagnostics.group_by(&:category)
        by_category.map do |category, ds|
          rules = ds.group_by(&:rule_id).sort_by { |_, group| -group.size }
          [category, rules]
        end.sort_by { |_, rules| -rules.sum { |_, g| g.size } }
      end

      def humanize(rule_id)
        rule_id.to_s.split("/").last.tr("-", " ").capitalize
      end

      def wrap(text)
        return "" unless text
        words = text.to_s.split
        lines = []
        current = ""
        words.each do |word|
          if (current.length + word.length + 1) > WRAP_WIDTH
            lines << current
            current = word
          else
            current = current.empty? ? word : "#{current} #{word}"
          end
        end
        lines << current unless current.empty?
        lines.join("\n")
      end

      def indent(text, n)
        prefix = " " * n
        text.to_s.each_line.map { |l| "#{prefix}#{l.chomp}" }.join("\n")
      end

      def score_block
        puts ""
        eyes, mouth = Score.face(score)
        bar_filled, bar_empty = Score.bar(score)
        score_color = score >= Score::GOOD_THRESHOLD ? :green : (score >= Score::OK_THRESHOLD ? :yellow : :red)
        score_line  = "#{color(score.to_s, score_color, :bold)} #{color("/ 100", :dim)} #{color(grade, score_color)}"
        bar_line    = color(bar_filled, score_color) + color(bar_empty, :dim)

        puts "  #{color('┌─────┐', :dim)}  #{score_line}"
        puts "  #{color("│ #{eyes} │", :dim)}  #{bar_line}"
        puts "  #{color("│ #{mouth} │", :dim)}  #{color(BRANDING, :dim)}"
        puts "  #{color('└─────┘', :dim)}"
        puts ""
      end

      def footer
        counts = result.diagnostics.group_by(&:severity).transform_values(&:size)
        issue_count = result.diagnostics.size
        affected = result.diagnostics.map(&:file).compact.uniq.size
        files_label = "across #{affected}/#{result.scanned_files} files"
        time_label = "in #{result.elapsed_ms}ms"
        puts color("  #{issue_count} issue#{issue_count == 1 ? '' : 's'} (#{counts[:error] || 0} error, #{counts[:warning] || 0} warning, #{counts[:info] || 0} info) #{files_label} #{time_label}", :dim)
        puts ""
      end
    end
  end
end
