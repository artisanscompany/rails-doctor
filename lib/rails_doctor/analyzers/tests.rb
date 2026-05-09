# frozen_string_literal: true

module RailsDoctor
  module Analyzers
    class Tests < Base
      private

      def analyze(diagnostics)
        if project.has_dir?("test") && project.has_dir?("spec") &&
           Dir.glob(project.path("test/**/*_test.rb").to_s).any? &&
           Dir.glob(project.path("spec/**/*_spec.rb").to_s).any?
          emit(diagnostics, :"tests/spec-and-test-coexist",
            message: "Both test/ and spec/ contain tests. Pick one framework — running both is fragile and confusing.",
            file: "spec/"
          )
        end

        check_factories_and_fixtures(diagnostics)
        check_url_over_path(diagnostics)
      end

      def check_factories_and_fixtures(diagnostics)
        factories = Dir.glob(project.path("{test,spec}/factories/**/*.rb").to_s)
        fixtures  = Dir.glob(project.path("test/fixtures/**/*.yml").to_s)
        return unless factories.any? && fixtures.any?

        emit(diagnostics, :"tests/factories-and-fixtures",
          message: "Both factory_bot factories (#{factories.size}) and fixtures (#{fixtures.size}) exist. Pick one — mixing both leads to hard-to-debug ordering issues.",
          file: "test/"
        )
      end

      def check_url_over_path(diagnostics)
        # Only flag Rails route URL helpers in obvious request/redirect contexts.
        Dir.glob(project.path("test/**/*_test.rb").to_s).each do |file|
          File.foreach(file).with_index(1) do |line, lineno|
            next unless line.match?(/\b(get|post|put|patch|delete|visit|assert_redirected_to|follow_redirect_to)\s+\w+_url\b/)
            emit(diagnostics, :"tests/url-over-path",
              message: "Test calls a `*_url` route helper. Prefer `*_path` — URL helpers force a host setup that adds noise to test failures.",
              file: relative(file),
              line: lineno
            )
            break
          end
        end
      end
    end
  end
end
