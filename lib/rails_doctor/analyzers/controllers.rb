# frozen_string_literal: true

require_relative "../ast"

module RailsDoctor
  module Analyzers
    class Controllers < Base
      RESTFUL_ACTIONS = %w[index show new create edit update destroy].freeze

      private

      def analyze(diagnostics)
        return unless project.has_dir?("app/controllers")

        Dir.glob(project.path("app/controllers/**/*.rb").to_s).each do |file|
          next if file.include?("/concerns/")
          rel = relative(file)
          tree = AST.parse_file(file)
          klass = AST.primary_class(tree)

          if rel == "app/controllers/application_controller.rb"
            check_application_controller(diagnostics, klass, file)
          elsif klass
            public_actions = AST.public_instance_methods(klass)
            non_rest = public_actions - RESTFUL_ACTIONS
            unless non_rest.empty?
              emit(diagnostics, :"controllers/non-restful-action",
                message: "#{rel.sub('app/controllers/', '')} defines non-RESTful public action(s): #{non_rest.join(', ')}. Extract each to a namespaced controller (e.g. `Posts::PublicationsController#create`).",
                file: rel
              )
            end

            check_before_actions(diagnostics, klass, rel)
          end

          loc = file_loc(file)
          if loc > threshold("controller_max_loc")
            emit(diagnostics, :"controllers/fat-controller",
              message: "#{rel.sub('app/controllers/', '')} is #{loc} lines (threshold #{threshold('controller_max_loc')}). Extract behavior to model methods, concerns, or split the resource.",
              file: rel
            )
          end

          check_n_plus_one_loop(diagnostics, file, rel)
          check_perform_now(diagnostics, file, rel)
        end
      end

      # Job.perform_now in a controller blocks the request thread on whatever
      # the job does — defeats the purpose of having a job. We allow it in
      # rake tasks and tests, just not controllers.
      def check_perform_now(diagnostics, file, rel)
        File.foreach(file).with_index(1) do |line, lineno|
          if line.match?(/\b\w+Job\.perform_now\b/)
            emit(diagnostics, :"jobs/perform-now-in-controller",
              message: "perform_now in a controller blocks the request thread. Use perform_later (or perform_async for Sidekiq) so the response goes out fast.",
              file: rel,
              line: lineno
            )
            break
          end
        end
      end

      # Heuristic N+1 detection: a controller method iterates a collection
      # and accesses an association on each element. We don't try to be
      # precise — if the result is annotated with `.includes(...)`, `preload`,
      # or `eager_load` somewhere in the action, we skip.
      def check_n_plus_one_loop(diagnostics, file, rel)
        src = File.read(file)
        # Find lines like `@things.each do |t|` or `things.map { |t| t.foo.bar }`.
        src.scan(/^(\s*)(@?\w+)\.(?:each|map|collect|find_each)\s*(?:do\s*\|(\w+)\||\{\s*\|(\w+)\|)/m).each do |indent, collection, var1, var2|
          var = var1 || var2
          next unless var
          # Look at the next ~6 lines for `.<var>.<assoc>.<method>` pattern.
          lines = src.lines
          lineno = src[0..src.index("#{collection}.")].count("\n") + 1 rescue 1
          window = lines[lineno - 1, 8]&.join("\n") || ""
          next unless window.match?(/\b#{var}\.\w+\.\w+/) # association.method
          next if src.match?(/#{Regexp.escape(collection)}.*?\.(?:includes|preload|eager_load|with)\b/m)
          emit(diagnostics, :"perf/n-plus-one-loop",
            message: "#{rel.sub('app/controllers/', '')} iterates #{collection} and reaches into associations on each element. Add `.includes(...)` or `.preload(...)` to prevent N+1 queries.",
            file: rel,
            line: lineno
          )
          break
        end
      end

      def check_application_controller(diagnostics, klass, file)
        loc = file_loc(file)
        before_actions = AST.macro_count(klass, :before_action)
        if loc > 30 || before_actions > 4
          emit(diagnostics, :"controllers/heavy-application-controller",
            message: "ApplicationController is #{loc} LOC with #{before_actions} before_actions. Move responsibilities into controller concerns.",
            file: relative(file)
          )
        end
      end

      def check_before_actions(diagnostics, klass, rel)
        before_actions = AST.macro_count(klass, :before_action)
        return if before_actions <= 5
        emit(diagnostics, :"controllers/before-action-overuse",
          message: "#{rel.sub('app/controllers/', '')} has #{before_actions} before_actions. Excessive filtering hides intent — consider consolidating into one or moving logic into the action.",
          file: rel
        )
      end
    end
  end
end
