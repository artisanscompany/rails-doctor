# frozen_string_literal: true

require "prism"

module RailsDoctor
  # Thin wrappers around Prism for the patterns we care about. Stdlib-only
  # (Prism is a default gem in Ruby 3.3+).
  module AST
    module_function

    def parse_file(path)
      return nil unless File.file?(path)
      Prism.parse_file(path).value
    rescue StandardError
      nil
    end

    # Returns the first ClassNode whose name matches the file's expected
    # constant (e.g. "users_controller.rb" → UsersController). Falls back to
    # the first class in the file.
    def primary_class(node)
      return nil unless node
      visit(node) { |n| return n if n.is_a?(Prism::ClassNode) }
      nil
    end

    # Yields every node in the tree.
    def visit(node, &block)
      return unless node
      yield node
      child_nodes(node).each { |c| visit(c, &block) if c }
    end

    def child_nodes(node)
      node.respond_to?(:child_nodes) ? Array(node.child_nodes) : []
    end

    # Public instance method names (def foo; ...; def self.bar excluded).
    def public_instance_methods(class_node)
      methods = []
      visibility = :public
      Array(class_node&.body&.body).each do |stmt|
        case stmt
        when Prism::CallNode
          name = stmt.name
          visibility = name if %i[private protected public].include?(name)
        when Prism::DefNode
          next if stmt.receiver # `def self.foo`
          methods << [stmt.name.to_s, visibility]
        end
      end
      methods.select { |_n, v| v == :public }.map(&:first)
    end

    def all_def_nodes(class_node)
      defs = []
      visit(class_node) { |n| defs << n if n.is_a?(Prism::DefNode) }
      defs
    end

    def all_call_names(class_node)
      names = []
      visit(class_node) { |n| names << n.name.to_s if n.is_a?(Prism::CallNode) }
      names
    end

    # Counts how many times a top-level macro is called inside the class body
    # (e.g. before_action, validates, has_many).
    def macro_count(class_node, macro)
      Array(class_node&.body&.body).count do |stmt|
        stmt.is_a?(Prism::CallNode) && stmt.name == macro
      end
    end

    def includes_concern?(class_node)
      Array(class_node&.body&.body).any? do |stmt|
        stmt.is_a?(Prism::CallNode) && stmt.name == :include
      end
    end
  end
end
