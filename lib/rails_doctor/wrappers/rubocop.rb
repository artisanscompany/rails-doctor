# frozen_string_literal: true

module RailsDoctor
  module Wrappers
    class Rubocop < Base
      BINARY = "rubocop"
      GEM = "rubocop"

      private

      def run
        diagnostics = []
        stdout, _stderr, _status = run_cmd(["rubocop", "--format", "json"])
        return diagnostics if stdout.empty?

        data = JSON.parse(stdout) rescue nil
        return diagnostics unless data.is_a?(Hash)

        Array(data["files"]).each do |file_entry|
          path = file_entry["path"]
          Array(file_entry["offenses"]).each do |o|
            next if o["severity"] == "refactor" || o["severity"] == "convention" && o["cop_name"].start_with?("Style/")
            emit(diagnostics, :"style/rubocop",
              message: "[#{o['cop_name']}] #{o['message']}",
              file: path,
              line: o.dig("location", "line")
            )
          end
        end
        diagnostics
      end
    end
  end
end
