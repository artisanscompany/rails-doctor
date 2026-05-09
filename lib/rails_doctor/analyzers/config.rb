# frozen_string_literal: true

module RailsDoctor
  module Analyzers
    # Environment-config drift: dev-only flags that leaked into production.rb,
    # production-only flags that snuck into development.rb, etc.
    class Config < Base
      DEV_ONLY_FLAGS = %w[
        consider_all_requests_local
        active_record.migration_error
        cache_classes
      ].freeze

      def analyze(diagnostics)
        check_dev_flags_in_production(diagnostics)
      end

      private

      def check_dev_flags_in_production(diagnostics)
        prod = project.path("config/environments/production.rb")
        return unless prod.exist?
        prod.read.each_line.with_index(1) do |line, lineno|
          # consider_all_requests_local = true → leaked debug pages
          if line.match?(/consider_all_requests_local\s*=\s*true/)
            emit(diagnostics, :"config/dev-flag-in-production",
              message: "production.rb sets consider_all_requests_local = true — visitors will see Rails error pages and stack traces.",
              file: relative(prod.to_s),
              line: lineno
            )
          end
          # raise_in_transactional_callbacks = false / cache_classes = false in prod
          if line.match?(/cache_classes\s*=\s*false/)
            emit(diagnostics, :"config/dev-flag-in-production",
              message: "production.rb sets cache_classes = false — code reloading is on in production.",
              file: relative(prod.to_s),
              line: lineno
            )
          end
        end
      end
    end
  end
end
