# frozen_string_literal: true

module RailsDoctor
  # Loads .rails-doctor.yml and exposes per-rule severity overrides.
  #
  # Schema:
  #   preset: default | strict | omakase | minimal
  #   allow:
  #     - sidekiq               # silence rules that depend on this stack choice
  #     - inertia-react
  #     - rspec
  #   disable:
  #     - controllers/non-restful-action
  #   severity:
  #     models/concern-too-large: error
  #   thresholds:
  #     concern_max_loc: 150
  #     controller_max_loc: 200
  #     model_max_loc: 400
  class Config
    DEFAULT_THRESHOLDS = {
      "concern_max_loc" => 150,
      "concern_min_loc" => 5,
      "controller_max_loc" => 200,
      "model_max_loc" => 400,
      "controller_max_actions" => 7
    }.freeze

    PRESETS = %w[default strict omakase minimal].freeze

    attr_reader :preset, :allow, :disable, :severity_overrides, :thresholds, :external

    def initialize(data = {})
      @preset = data["preset"] || "default"
      @allow = Array(data["allow"]).map(&:to_s)
      @disable = Array(data["disable"]).map(&:to_s)
      @severity_overrides = data["severity"] || {}
      @thresholds = DEFAULT_THRESHOLDS.merge(data["thresholds"] || {})
      @external = data["external"] || {}
    end

    def self.load(root)
      path = Pathname.new(root).join(".rails-doctor.yml")
      return new unless path.exist?

      data = YAML.safe_load(path.read, permitted_classes: [Symbol], aliases: true) || {}
      new(data)
    end

    def disabled?(rule_id)
      disable.include?(rule_id.to_s)
    end

    def allowed?(token)
      allow.include?(token.to_s)
    end

    def severity_for(rule)
      override = severity_overrides[rule.id.to_s]
      return override.to_sym if override
      return :error if preset == "strict" && rule.default_severity == :warning
      return :info if preset == "minimal" && rule.default_severity == :warning
      rule.default_severity
    end

    def threshold(name)
      thresholds[name.to_s]
    end

    def external_enabled?(tool)
      return true if @external["enabled"] == true
      Array(@external["tools"]).include?(tool.to_s)
    end
  end
end
