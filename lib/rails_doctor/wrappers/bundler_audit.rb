# frozen_string_literal: true

module RailsDoctor
  module Wrappers
    class BundlerAudit < Base
      BINARY = "bundle-audit"
      GEM = "bundler-audit"

      private

      def run
        diagnostics = []
        stdout, _stderr, _status = run_cmd(["bundle-audit", "check", "--update"])
        return diagnostics if stdout.empty?

        # bundler-audit's text output is line-based; no JSON. Parse blocks.
        stdout.split(/^Name: /).drop(1).each do |block|
          name = block.lines.first&.strip
          version = block.match(/^Version: (.+)$/)&.captures&.first
          advisory = block.match(/^Advisory: (.+)$/)&.captures&.first
          criticality = block.match(/^Criticality: (.+)$/)&.captures&.first
          title = block.match(/^Title: (.+)$/)&.captures&.first
          next unless name

          emit(diagnostics, :"security/bundler-audit",
            message: "#{name} #{version}: #{title} (#{advisory}, #{criticality})",
            file: "Gemfile.lock"
          )
        end
        diagnostics
      end
    end
  end
end
