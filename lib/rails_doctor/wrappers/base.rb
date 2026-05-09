# frozen_string_literal: true

require "open3"

module RailsDoctor
  module Wrappers
    class Base
      attr_reader :project, :config

      def initialize(project, config)
        @project = project
        @config = config
      end

      def self.available?(project)
        binary_available?(self::BINARY) || project.has_gem?(self::GEM)
      rescue NameError
        false
      end

      def self.binary_available?(name)
        return false unless name
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, name)) }
      end

      def call
        return [] unless self.class.available?(project)
        run
      end

      private

      def run
        raise NotImplementedError
      end

      def run_cmd(cmd, env: {}, chdir: project.root.to_s)
        Open3.capture3(env, *cmd, chdir: chdir)
      rescue StandardError
        ["", "", nil]
      end

      def emit(diagnostics, rule_id, message:, file: nil, line: nil, fix: nil)
        rule = Registry.fetch(rule_id)
        diagnostics << Diagnostic.new(
          rule_id: rule_id,
          severity: rule.default_severity,
          message: message,
          fix: fix || rule.default_fix,
          file: file,
          line: line,
          category: rule.category,
          doc_url: rule.doc_url
        )
      end
    end
  end
end
