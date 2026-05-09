# frozen_string_literal: true

module RailsDoctor
  module Wrappers
    class Traceroute < Base
      BINARY = nil
      GEM = "traceroute"

      def self.available?(project)
        project.has_gem?("traceroute")
      end

      private

      def run
        diagnostics = []
        stdout, _stderr, _status = run_cmd(["bundle", "exec", "rake", "traceroute"])
        return diagnostics if stdout.empty?

        section = nil
        stdout.each_line do |line|
          stripped = line.strip
          if stripped.start_with?("Unused routes")
            section = :unused_routes
          elsif stripped.start_with?("Routed actions not connected")
            section = :unconnected
          elsif stripped.empty?
            section = nil
          elsif section
            emit(diagnostics, :"dead/traceroute",
              message: "[#{section}] #{stripped}",
              file: "config/routes.rb"
            )
          end
        end
        diagnostics
      end
    end
  end
end
