# frozen_string_literal: true

module RailsDoctor
  module Wrappers
    class Brakeman < Base
      BINARY = "brakeman"
      GEM = "brakeman"

      private

      def run
        diagnostics = []
        stdout, _stderr, _status = run_cmd(["brakeman", "-q", "-f", "json", "--no-pager"])
        return diagnostics if stdout.empty?

        data = JSON.parse(stdout) rescue nil
        return diagnostics unless data.is_a?(Hash)

        Array(data["warnings"]).each do |w|
          severity = case w["confidence"]
                     when "High" then "high"
                     when "Medium" then "medium"
                     else "low"
                     end
          msg = "[#{w['warning_type']}, #{severity} confidence] #{w['message']}"
          emit(diagnostics, :"security/brakeman",
            message: msg,
            file: w["file"],
            line: w["line"]
          )
        end
        diagnostics
      end
    end
  end
end
