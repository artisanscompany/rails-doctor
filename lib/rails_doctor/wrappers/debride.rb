# frozen_string_literal: true

module RailsDoctor
  module Wrappers
    class Debride < Base
      BINARY = "debride"
      GEM = "debride"

      private

      def run
        diagnostics = []
        stdout, _stderr, _status = run_cmd(["debride", "app", "lib"])
        return diagnostics if stdout.empty?

        # Lines look like:
        #   ClassName
        #     method_name  app/foo/bar.rb:12
        current_class = nil
        stdout.each_line do |line|
          if line.match?(/^\S/)
            current_class = line.strip
          elsif (m = line.strip.match(/^(\S+)\s+(\S+):(\d+)/))
            method, file, lineno = m.captures
            emit(diagnostics, :"dead/debride",
              message: "#{current_class}##{method} appears unused.",
              file: file,
              line: lineno.to_i
            )
          end
        end
        diagnostics
      end
    end
  end
end
