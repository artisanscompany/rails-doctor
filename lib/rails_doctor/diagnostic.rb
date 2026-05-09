# frozen_string_literal: true

module RailsDoctor
  SEVERITIES = %i[error warning info].freeze
  SEVERITY_WEIGHTS = { error: 5.0, warning: 2.0, info: 0.5 }.freeze

  Diagnostic = Struct.new(
    :rule_id, :severity, :message, :fix, :file, :line, :category, :doc_url,
    keyword_init: true
  ) do
    def to_h
      super.compact
    end

    def location
      [file, line].compact.join(":")
    end

    def weight
      SEVERITY_WEIGHTS.fetch(severity, 0.0)
    end
  end
end
