# frozen_string_literal: true

module RailsDoctor
  module Analyzers
    # Lightweight security checks layered on top of Brakeman's wrapper. These
    # catch the everyday patterns that show up in agent-written code — they
    # don't replace Brakeman, they catch things faster on every save.
    class Security < Base
      SECRET_PATTERNS = [
        # API key / token literals — match common providers + generic patterns.
        [/sk_live_[A-Za-z0-9]{20,}/,            "Stripe live secret key"],
        [/sk_test_[A-Za-z0-9]{20,}/,            "Stripe test secret key"],
        [/AKIA[0-9A-Z]{16}/,                    "AWS access key id"],
        [/AIza[0-9A-Za-z_\-]{35}/,              "Google API key"],
        [/ghp_[A-Za-z0-9]{36}/,                 "GitHub personal access token"],
        [/xox[baprs]-[A-Za-z0-9-]{10,}/,        "Slack token"],
        [/-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----/, "Private key block"],
      ].freeze

      def analyze(diagnostics)
        check_secrets(diagnostics)
        check_skip_csrf(diagnostics)
        check_permit_all(diagnostics)
        check_raw_sql(diagnostics)
      end

      private

      def check_secrets(diagnostics)
        Dir.glob(project.path("{app,config,lib}/**/*.{rb,erb,yml}").to_s).each do |file|
          # Don't read encrypted credentials.
          next if file.end_with?("credentials.yml.enc")
          File.foreach(file).with_index(1) do |line, lineno|
            SECRET_PATTERNS.each do |pattern, label|
              if line.match?(pattern)
                emit(diagnostics, :"security/secret-in-code",
                  message: "#{label} appears in source. Move to Rails encrypted credentials or ENV.",
                  file: relative(file),
                  line: lineno
                )
                break # one finding per line is enough
              end
            end
          end
        end
      end

      SKIP_CSRF_RE = /skip_before_action\s+:verify_authenticity_token/

      def check_skip_csrf(diagnostics)
        Dir.glob(project.path("app/controllers/**/*.rb").to_s).each do |file|
          File.foreach(file).with_index(1) do |line, lineno|
            next unless line.match?(SKIP_CSRF_RE)
            # API controllers (api/v*/) commonly skip CSRF and use token auth — skip those.
            next if file.match?(%r{controllers/api(?:/|_)})
            emit(diagnostics, :"security/skip-csrf",
              message: "Skipping CSRF verification on a non-API controller exposes the action to cross-site forgery.",
              file: relative(file),
              line: lineno
            )
          end
        end
      end

      def check_permit_all(diagnostics)
        Dir.glob(project.path("app/controllers/**/*.rb").to_s).each do |file|
          File.foreach(file).with_index(1) do |line, lineno|
            if line.match?(/\bparams\.permit!/)
              emit(diagnostics, :"security/permit-all-params",
                message: "params.permit! accepts arbitrary attributes — strong params is bypassed.",
                file: relative(file),
                line: lineno
              )
            end
          end
        end
      end

      # Detect raw SQL with string interpolation in `where(...)`, `find_by_sql`,
      # or `execute(...)`. False positives possible (interpolated table names,
      # constants), so severity is warning, not error.
      RAW_SQL_RE = /\b(?:where|find_by_sql|execute)\s*\(\s*["'][^"']*#\{/

      def check_raw_sql(diagnostics)
        Dir.glob(project.path("{app,lib}/**/*.rb").to_s).each do |file|
          File.foreach(file).with_index(1) do |line, lineno|
            next unless line.match?(RAW_SQL_RE)
            # ORDER BY with a known constant is the most common false-positive shape.
            next if line.match?(/order\(/)
            emit(diagnostics, :"security/raw-sql-interpolation",
              message: "Raw SQL with string interpolation. Use parameterized queries: where(\"col = ?\", value).",
              file: relative(file),
              line: lineno
            )
          end
        end
      end
    end
  end
end
