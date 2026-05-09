# frozen_string_literal: true

module RailsDoctor
  # Aggregates diagnostics into a single 0-100 health score.
  # Severity weights: error=5, warning=2, info=0.5.
  # Per-rule contribution capped so one noisy rule cannot dominate.
  class Score
    PER_RULE_CAP = 20.0
    GRADES = [
      [75, "Great"],
      [50, "Needs work"],
      [0, "Critical"]
    ].freeze

    def self.compute(diagnostics)
      return 100 if diagnostics.empty?

      grouped = diagnostics.group_by(&:rule_id)
      deduction = grouped.sum do |_id, ds|
        raw = ds.sum(&:weight)
        [raw, PER_RULE_CAP].min
      end

      [(100 - deduction).round, 0].max
    end

    def self.grade(score)
      GRADES.find { |threshold, _| score >= threshold }&.last || "Critical"
    end
  end
end
