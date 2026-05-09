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
        check_factory_create_overuse(diagnostics)
      end

      # Test files where every assertion is preceded by `create(:foo)` are
      # slow (every test hits the DB). build_stubbed is faster when you don't
      # need persistence. We flag files where create() vastly outweighs
      # build_stubbed and the test count is meaningful.
      def check_factory_create_overuse(diagnostics)
        Dir.glob(project.path("{test,spec}/**/*_{test,spec}.rb").to_s).each do |file|
          src = File.read(file)
          creates = src.scan(/\bcreate\(:\w+/).size
          stubbed = src.scan(/\bbuild_stubbed\(:\w+/).size
          test_count = src.scan(/^\s*(?:test|it|describe|context)\s+["']/).size
          next if test_count < 3
          next if creates < 10
          next if stubbed > 0  # team already knows about build_stubbed

          emit(diagnostics, :"tests/factory-create-overuse",
            message: "#{relative(file)} uses create() #{creates} times across #{test_count} examples and never build_stubbed(). Stubbed factories are 10–100× faster when you don't need DB persistence.",
            file: relative(file)
          )
        end
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
