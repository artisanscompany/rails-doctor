# frozen_string_literal: true

require_relative "analyzers/base"
require_relative "analyzers/architecture"
require_relative "analyzers/gemfile"
require_relative "analyzers/routes"
require_relative "analyzers/controllers"
require_relative "analyzers/models"
require_relative "analyzers/migrations"
require_relative "analyzers/views"
require_relative "analyzers/tests"
require_relative "analyzers/stack"

require_relative "wrappers/base"
require_relative "wrappers/brakeman"
require_relative "wrappers/bundler_audit"
require_relative "wrappers/active_record_doctor"
require_relative "wrappers/rubocop"
require_relative "wrappers/reek"
require_relative "wrappers/debride"
require_relative "wrappers/traceroute"
require_relative "wrappers/rubycritic"

module RailsDoctor
  # Orchestrates analyzers, wrappers, and detection-phase output.
  # Produces { diagnostics:, scanned_files:, total_files:, elapsed_ms:, detection: }.
  class Runner
    ANALYZERS = [
      ["architecture", Analyzers::Architecture],
      ["Gemfile",      Analyzers::Gemfile],
      ["routes",       Analyzers::Routes],
      ["controllers",  Analyzers::Controllers],
      ["models",       Analyzers::Models],
      ["migrations",   Analyzers::Migrations],
      ["views",        Analyzers::Views],
      ["tests",        Analyzers::Tests],
      ["stack",        Analyzers::Stack]
    ].freeze

    WRAPPERS = {
      "brakeman" => Wrappers::Brakeman,
      "bundler-audit" => Wrappers::BundlerAudit,
      "active_record_doctor" => Wrappers::ActiveRecordDoctor,
      "rubocop" => Wrappers::Rubocop,
      "reek" => Wrappers::Reek,
      "debride" => Wrappers::Debride,
      "traceroute" => Wrappers::Traceroute,
      "rubycritic" => Wrappers::Rubycritic
    }.freeze

    attr_reader :project, :config, :options

    def initialize(project, config:, options: {})
      @project = project
      @config = config
      @options = options
    end

    # Returns a Result struct.
    def run
      started = monotonic
      diagnostics = []
      ANALYZERS.each do |_label, klass|
        diagnostics.concat(safely { klass.new(project, config).call })
      end

      external_run = []
      if options[:with_external] != false
        WRAPPERS.each do |name, klass|
          next unless klass.available?(project)
          next unless config.external_enabled?(name) || options[:with_external] == :all
          external_run << name
          diagnostics.concat(safely { klass.new(project, config).call })
        end
      end

      diagnostics = diagnostics
        .reject { |d| config.disabled?(d.rule_id) }
        .map { |d| apply_severity(d) }

      diagnostics = filter_by_diff(diagnostics) if options[:diff_files]

      Result.new(
        diagnostics: diagnostics,
        analyzers: ANALYZERS.map(&:first),
        external: external_run,
        scanned_files: count_scanned_files,
        total_files: count_total_files,
        elapsed_ms: ((monotonic - started) * 1000).round
      )
    end

    Result = Struct.new(:diagnostics, :analyzers, :external, :scanned_files, :total_files, :elapsed_ms, keyword_init: true)

    private

    def safely
      yield || []
    rescue => e
      warn "rails-doctor: analyzer error: #{e.class}: #{e.message}" if options[:verbose]
      []
    end

    def apply_severity(diagnostic)
      rule = Registry.fetch(diagnostic.rule_id)
      diagnostic.severity = config.severity_for(rule)
      diagnostic
    end

    def filter_by_diff(diagnostics)
      changed = options[:diff_files]
      return diagnostics if changed.empty?
      diagnostics.select { |d| d.file.nil? || changed.any? { |f| d.file == f || d.file.start_with?(f) } }
    end

    def count_total_files
      Dir.glob(project.path("app/**/*.{rb,erb,js,jsx,ts,tsx}").to_s).size +
        Dir.glob(project.path("config/**/*.rb").to_s).size +
        Dir.glob(project.path("db/migrate/*.rb").to_s).size
    end

    def count_scanned_files
      # Files that an analyzer would have read.
      Dir.glob(project.path("app/{controllers,models,views,jobs,helpers,channels,javascript}/**/*.{rb,erb,js}").to_s).size +
        Dir.glob(project.path("config/routes.rb").to_s).size +
        Dir.glob(project.path("db/migrate/*.rb").to_s).size +
        Dir.glob(project.path("Gemfile").to_s).size
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
