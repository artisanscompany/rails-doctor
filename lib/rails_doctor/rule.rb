# frozen_string_literal: true

module RailsDoctor
  Rule = Struct.new(:id, :title, :category, :default_severity, :doc_url, :description, keyword_init: true) do
    def to_h
      super.compact
    end
  end
end
