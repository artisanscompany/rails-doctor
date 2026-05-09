# frozen_string_literal: true

require "optparse"
require_relative "reporters/tty"
require_relative "reporters/json"
require_relative "reporters/markdown"

module RailsDoctor
  module CLI
    USAGE = <<~USAGE
      Usage: rails-doctor <command> [options]

      Commands:
        scan [path]         Scan a Rails project (default if first arg is a path)
        install             Install rails-doctor as a skill in detected coding agents
        explain <rule-id>   Show docs for a rule
        rules               List all rules
        version             Print version
        help                Show this message
    USAGE

    def self.start(argv)
      argv = argv.dup
      command = pick_command(argv)

      case command
      when "scan"            then Scan.run(argv)
      when "install"         then Install.run(argv)
      when "explain"         then Explain.run(argv)
      when "rules"           then Rules.run(argv)
      when "version", "-v", "--version" then puts "rails-doctor #{RailsDoctor::VERSION}"
      when "help", "-h", "--help", nil  then puts USAGE
      else
        if File.directory?(command) || command == "."
          argv.unshift(command)
          Scan.run(argv)
        else
          warn "rails-doctor: unknown command '#{command}'"
          warn USAGE
          exit 2
        end
      end
    end

    def self.pick_command(argv)
      first = argv.first
      return nil if first.nil?
      return argv.shift if %w[scan install explain rules version help -v --version -h --help].include?(first)
      argv.shift
    end

    module Scan
      def self.run(argv)
        options = {
          json: false,
          markdown: false,
          strict: false,
          preset: nil,
          with_external: "auto",
          no_color: false,
          verbose: false,
          full: false,
          score_only: false,
          min_score: nil,
          fail_on: "none",
          diff: nil
        }
        path = "."

        parser = OptionParser.new do |o|
          o.banner = "Usage: rails-doctor scan [path] [options]"
          o.on("--json")               { options[:json] = true }
          o.on("--markdown")           { options[:markdown] = true }
          o.on("--strict")             { options[:strict] = true }
          o.on("--verbose")            { options[:verbose] = true }
          o.on("--full")               { options[:full] = true }
          o.on("--score")              { options[:score_only] = true }
          o.on("--preset PRESET")      { |v| options[:preset] = v }
          o.on("--with-external MODE") { |v| options[:with_external] = v }
          o.on("--no-color")           { options[:no_color] = true }
          o.on("--min-score N", Integer) { |v| options[:min_score] = v }
          o.on("--fail-on LEVEL")      { |v| options[:fail_on] = v }
          o.on("--diff [BASE]")        { |v| options[:diff] = v || "main" }
        end
        positional = parser.parse(argv)
        path = positional.first if positional.first

        project = Project.new(path)
        unless project.rails_app?
          warn "rails-doctor: no Rails project found at #{project.root}"
          exit 2
        end

        config = Config.load(project.root)
        config = override_preset(config, options[:preset]) if options[:preset]

        runner_opts = {
          verbose: options[:verbose],
          with_external: external_mode(options[:with_external])
        }
        runner_opts[:diff_files] = compute_diff_files(project, options[:diff]) if options[:diff]

        result = Runner.new(project, config: config, options: runner_opts).run
        result.diagnostics.replace(promote_to_errors(result.diagnostics)) if options[:strict]

        score = Score.compute(result.diagnostics)
        grade = Score.grade(score)

        if options[:score_only]
          puts score
          exit_with_policy(score, options, result.diagnostics)
        end

        reporter_class =
          if options[:json]     then Reporters::Json
          elsif options[:markdown] then Reporters::Markdown
          else Reporters::Tty
          end

        reporter_class.new(
          project: project, result: result,
          score: score, grade: grade,
          options: { no_color: options[:no_color], verbose: options[:verbose], full: options[:full] }
        ).render

        exit_with_policy(score, options, result.diagnostics)
      end

      def self.exit_with_policy(score, options, diagnostics)
        exit 1 if options[:min_score] && score < options[:min_score]
        case options[:fail_on]
        when "error"   then exit 1 if diagnostics.any? { |d| d.severity == :error }
        when "warning" then exit 1 if diagnostics.any? { |d| %i[error warning].include?(d.severity) }
        end
        exit 0
      end

      def self.override_preset(config, preset)
        Config.new("preset" => preset,
                   "allow" => config.allow,
                   "disable" => config.disable,
                   "severity" => config.severity_overrides,
                   "thresholds" => config.thresholds,
                   "external" => config.external)
      end

      def self.promote_to_errors(diagnostics)
        diagnostics.map do |d|
          d.severity = :error if d.severity == :warning
          d
        end
      end

      def self.external_mode(value)
        case value
        when "off", "false", "no" then false
        when "all"                then :all
        else                           true
        end
      end

      # Returns a list of repo-relative paths (or nil to skip diff filtering).
      def self.compute_diff_files(project, base)
        out = `cd "#{project.root}" && git diff --name-only "#{base}"...HEAD 2>/dev/null && git diff --name-only --cached 2>/dev/null && git diff --name-only 2>/dev/null`
        files = out.lines.map(&:strip).reject(&:empty?).uniq
        files.empty? ? nil : files
      end
    end

    module Install
      def self.run(argv)
        options = { dry_run: false, yes: false }
        OptionParser.new do |o|
          o.banner = "Usage: rails-doctor install [options]"
          o.on("--dry-run") { options[:dry_run] = true }
          o.on("-y", "--yes") { options[:yes] = true }
        end.parse(argv)
        Installer.new(dry_run: options[:dry_run], yes: options[:yes]).run
      end
    end

    module Explain
      def self.run(argv)
        rule_id = argv.shift
        unless rule_id
          warn "Usage: rails-doctor explain <rule-id>"
          exit 2
        end
        rule = Registry.fetch(rule_id.to_sym)
        puts "#{rule.id}  (#{rule.category}, default: #{rule.default_severity})"
        puts rule.title
        puts ""
        puts "Fix: #{rule.default_fix}" if rule.default_fix
        puts rule.description if rule.description
        puts rule.doc_url    if rule.doc_url
      rescue Error => e
        warn e.message
        exit 2
      end
    end

    module Rules
      def self.run(_argv)
        Registry.all.sort_by { |r| [r.category.to_s, r.id.to_s] }.each do |r|
          puts "  #{r.default_severity.to_s.ljust(8)} #{r.category.to_s.ljust(14)} #{r.id}"
        end
      end
    end
  end
end
