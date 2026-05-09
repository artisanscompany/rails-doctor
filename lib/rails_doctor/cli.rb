# frozen_string_literal: true

require "optparse"
require_relative "reporters/tty"
require_relative "reporters/json"
require_relative "reporters/markdown"

module RailsDoctor
  # Stdlib-only CLI (no Thor) so rails-doctor runs on any Ruby installation
  # without `bundle install`. Mirrors react-doctor's UX:
  #   rails-doctor scan [path] [flags]
  #   rails-doctor install [--dry-run] [--yes]
  #   rails-doctor explain <rule-id>
  #   rails-doctor rules
  #   rails-doctor version
  module CLI
    USAGE = <<~USAGE
      Usage: rails-doctor <command> [options]

      Commands:
        scan [path]         Scan a Rails project (default command if path is given)
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
        # If the first arg looks like a path, treat as `scan PATH`
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
          min_score: nil
        }
        path = "."

        parser = OptionParser.new do |o|
          o.banner = "Usage: rails-doctor scan [path] [options]"
          o.on("--json")               { options[:json] = true }
          o.on("--markdown")           { options[:markdown] = true }
          o.on("--strict")             { options[:strict] = true }
          o.on("--preset PRESET")      { |v| options[:preset] = v }
          o.on("--with-external MODE") { |v| options[:with_external] = v }
          o.on("--no-color")           { options[:no_color] = true }
          o.on("-v", "--verbose")      { options[:verbose] = true }
          o.on("--min-score N", Integer) { |v| options[:min_score] = v }
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
        diagnostics = Runner.new(project, config: config, options: runner_opts).run
        diagnostics = promote_to_errors(diagnostics) if options[:strict]

        score = Score.compute(diagnostics)
        grade = Score.grade(score)

        reporter_class =
          if options[:json]     then Reporters::Json
          elsif options[:markdown] then Reporters::Markdown
          else Reporters::Tty
          end

        reporter_class.new(
          project: project, diagnostics: diagnostics,
          score: score, grade: grade,
          options: { no_color: options[:no_color] }
        ).render

        exit 1 if options[:min_score] && score < options[:min_score]
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
