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
  class Runner
    ANALYZERS = [
      Analyzers::Architecture,
      Analyzers::Gemfile,
      Analyzers::Routes,
      Analyzers::Controllers,
      Analyzers::Models,
      Analyzers::Migrations,
      Analyzers::Views,
      Analyzers::Tests,
      Analyzers::Stack
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

    def run
      diagnostics = []
      ANALYZERS.each do |klass|
        diagnostics.concat(safely { klass.new(project, config).call })
      end

      if options[:with_external]
        WRAPPERS.each do |name, klass|
          next unless klass.available?(project)
          next unless config.external_enabled?(name) || options[:with_external] == :all
          diagnostics.concat(safely { klass.new(project, config).call })
        end
      end

      diagnostics
        .reject { |d| config.disabled?(d.rule_id) }
        .map { |d| apply_severity(d) }
    end

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
  end
end
