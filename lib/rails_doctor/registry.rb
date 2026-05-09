# frozen_string_literal: true

module RailsDoctor
  class Registry
    CATEGORIES = %i[
      doctrine
      omakase
      architecture
      models
      controllers
      routes
      views
      jobs
      database
      tests
      stack
      security
      performance
      dead_code
      smells
      deployment
      house
    ].freeze

    @rules = {}

    class << self
      attr_reader :rules

      def define(id, title:, category:, default_severity: :warning, doc_url: nil, description: nil)
        rule = Rule.new(
          id: id,
          title: title,
          category: category,
          default_severity: default_severity,
          doc_url: doc_url,
          description: description
        )
        @rules[id] = rule
        rule
      end

      def fetch(id)
        @rules[id] || raise(Error, "Unknown rule: #{id}")
      end

      def all
        @rules.values
      end

      def by_category(category)
        @rules.values.select { |r| r.category == category }
      end
    end
  end
end

require_relative "rules"
