# frozen_string_literal: true

require "yaml"
require "set"

module RailsDoctor
  module Analyzers
    # Light-weight i18n hygiene checks. Loads every YAML file under
    # `config/locales/`, builds the set of dotted keys, then greps the codebase
    # for `t("...")` / `t(:..., scope: "...")` / `I18n.t("...")` calls and
    # cross-references. We only flag *literal* keys — dynamic ones (`t(some_var)`)
    # can't be statically verified and are skipped silently.
    class I18n < Base
      LOCALE_GLOB = "config/locales/**/*.yml"
      RB_GLOBS = %w[
        app/**/*.rb
        app/**/*.erb
        app/**/*.rake
        app/**/*.haml
        app/**/*.slim
      ].freeze

      def analyze(diagnostics)
        locale_files = Dir.glob(project.path(LOCALE_GLOB).to_s)
        return if locale_files.empty?

        defined_keys = collect_defined_keys(locale_files)
        return if defined_keys.empty?

        used_keys = collect_used_keys
        return if used_keys.empty?

        # missing-translation: literal keys referenced from code that aren't
        # defined in any locale file.
        used_keys.each do |key, locations|
          # Skip pluralized lookups — Rails appends ".one"/".other" at lookup time.
          next if defined_keys.include?(key)
          next if defined_keys.include?("#{key}.one") || defined_keys.include?("#{key}.other")
          # Skip likely-dynamic keys like "errors.messages.#{kind}".
          next if key.include?("#")
          loc = locations.first
          emit(diagnostics, :"i18n/missing-translation",
            message: "t(\"#{key}\") referenced but not defined in any config/locales/*.yml file.",
            file: loc[:file],
            line: loc[:line]
          )
        end

        # unused-translation: keys defined in the en.yml locale but never used in
        # code. Limit to en (the source of truth) so we don't flag intentional
        # placeholder translations in fr/es/etc.
        en_keys = defined_keys.select { |k| k.start_with?("en.") }.map { |k| k.sub(/^en\./, "") }
        used_set = used_keys.keys.to_set
        unused = en_keys.reject do |k|
          used_set.include?(k) || used_set.any? { |u| u.start_with?("#{k}.") || k.start_with?("#{u}.") }
        end
        # Keep the noise sane on big apps: only flag the first batch.
        unused.first(30).each do |k|
          emit(diagnostics, :"i18n/unused-translation",
            message: "Locale key \"#{k}\" is defined in config/locales but never referenced.",
            file: "config/locales"
          )
        end
      end

      private

      def collect_defined_keys(locale_files)
        keys = Set.new
        locale_files.each do |file|
          data = (YAML.safe_load(File.read(file), aliases: true) rescue nil)
          next unless data.is_a?(Hash)
          flatten_keys(data).each { |k| keys.add(k) }
        end
        keys
      end

      def flatten_keys(hash, prefix = nil)
        keys = []
        hash.each do |k, v|
          full = prefix ? "#{prefix}.#{k}" : k.to_s
          if v.is_a?(Hash)
            keys.concat(flatten_keys(v, full))
          else
            keys << full
          end
        end
        keys
      end

      # Collects literal-string keys referenced in code. Returns
      # { "users.show.title" => [{file:, line:}, ...] }.
      def collect_used_keys
        out = Hash.new { |h, k| h[k] = [] }
        RB_GLOBS.each do |pattern|
          Dir.glob(project.path(pattern).to_s).each do |file|
            File.foreach(file).with_index(1) do |line, lineno|
              line.scan(/\b(?:I18n\.)?t\(\s*["']([\w.\-]+)["']/) do |match|
                key = match[0]
                next if key.include?(" ")
                out[key] << { file: relative(file), line: lineno }
              end
            end
          end
        end
        out
      end
    end
  end
end
