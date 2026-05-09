# frozen_string_literal: true

module RailsDoctor
  module Wrappers
    class ActiveRecordDoctor < Base
      BINARY = nil # rails-only, runs via `bundle exec rails active_record_doctor`
      GEM = "active_record_doctor"

      def self.available?(project)
        project.has_gem?("active_record_doctor")
      end

      private

      def run
        diagnostics = []
        stdout, _stderr, _status = run_cmd(["bundle", "exec", "rails", "active_record_doctor"])
        return diagnostics if stdout.empty?

        # active_record_doctor prints task-name banners then findings. We map findings opaquely.
        stdout.each_line do |line|
          stripped = line.strip
          next if stripped.empty? || stripped.start_with?("running ", "I, [", "D, [", "Warning:")
          emit(diagnostics, :"db/active-record-doctor", message: stripped, file: "db/")
        end
        diagnostics
      end
    end
  end
end
