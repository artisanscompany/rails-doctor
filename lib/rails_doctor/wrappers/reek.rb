# frozen_string_literal: true

module RailsDoctor
  module Wrappers
    class Reek < Base
      BINARY = "reek"
      GEM = "reek"

      private

      def run
        diagnostics = []
        stdout, _stderr, _status = run_cmd(["reek", "--format", "json", "app", "lib"])
        return diagnostics if stdout.empty?

        data = JSON.parse(stdout) rescue nil
        return diagnostics unless data.is_a?(Array)

        data.each do |smell|
          emit(diagnostics, :"smells/reek",
            message: "[#{smell['smell_type']}] #{smell['message']} in #{smell['context']}",
            file: smell["source"],
            line: Array(smell["lines"]).first
          )
        end
        diagnostics
      end
    end
  end
end
