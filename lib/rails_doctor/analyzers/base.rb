# frozen_string_literal: true

module RailsDoctor
  module Analyzers
    class Base
      attr_reader :project, :config

      def initialize(project, config)
        @project = project
        @config = config
      end

      def call
        diagnostics = []
        analyze(diagnostics)
        diagnostics
      end

      private

      def analyze(_diagnostics)
        raise NotImplementedError
      end

      def emit(diagnostics, rule_id, message:, file: nil, line: nil, fix: nil)
        rule = Registry.fetch(rule_id)
        diagnostics << Diagnostic.new(
          rule_id: rule_id,
          severity: rule.default_severity,
          message: message,
          fix: fix || rule.default_fix,
          file: relative(file),
          line: line,
          category: rule.category,
          doc_url: rule.doc_url
        )
      end

      def relative(file)
        return nil unless file
        path = Pathname.new(file)
        return file if path.relative?
        path.relative_path_from(project.root).to_s
      rescue ArgumentError
        file
      end

      def threshold(name)
        config.threshold(name)
      end

      def allowed?(token)
        config.allowed?(token)
      end

      def each_ruby_line(file)
        return unless File.file?(file)
        File.foreach(file).with_index(1) do |line, lineno|
          yield line, lineno
        end
      end

      def file_loc(file)
        return 0 unless File.file?(file)
        File.read(file).each_line.count { |l| l.strip != "" && !l.strip.start_with?("#") }
      end
    end
  end
end
