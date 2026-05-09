# frozen_string_literal: true

require "set"

module RailsDoctor
  # Score = 100 minus per-unique-rule penalties:
  #   error rule  =  1.5
  #   warning rule = 0.75
  # So one rule firing 100 times still only deducts 0.75 (or 1.5).
  # Score reflects how *diverse* the breakage is, not how *many* findings exist.
  # Mirrors react-doctor's calculate-score-locally.ts.
  class Score
    PERFECT             = 100
    ERROR_RULE_PENALTY  = 1.5
    WARNING_RULE_PENALTY = 0.75
    GOOD_THRESHOLD      = 75
    OK_THRESHOLD        = 50
    BAR_WIDTH           = 50

    GRADES = {
      good: "Great",
      ok:   "Needs work",
      bad:  "Critical"
    }.freeze

    def self.compute(diagnostics)
      error_rules = Set.new
      warning_rules = Set.new
      diagnostics.each do |d|
        case d.severity
        when :error   then error_rules << d.rule_id
        when :warning then warning_rules << d.rule_id
        end
      end
      penalty = error_rules.size * ERROR_RULE_PENALTY + warning_rules.size * WARNING_RULE_PENALTY
      [(PERFECT - penalty).round, 0].max
    end

    def self.grade(score)
      return GRADES[:good] if score >= GOOD_THRESHOLD
      return GRADES[:ok]   if score >= OK_THRESHOLD
      GRADES[:bad]
    end

    def self.bar(score)
      filled = ((score.to_f / PERFECT) * BAR_WIDTH).round
      ["█" * filled, "░" * (BAR_WIDTH - filled)]
    end

    def self.face(score)
      return ["◠ ◠", " ▽ "] if score >= GOOD_THRESHOLD
      return ["• •", " ─ "] if score >= OK_THRESHOLD
      ["× ×", " ︵ "]
    end
  end
end
