# frozen_string_literal: true

module RailsDoctor
  module Analyzers
    class Views < Base
      private

      def analyze(diagnostics)
        bundlers = []
        bundlers << "importmap-rails" if project.importmap?
        bundlers << "jsbundling-rails" if project.jsbundling?
        bundlers << "vite_rails" if project.vite?
        bundlers << "webpacker" if project.webpacker?

        if bundlers.size > 1
          emit(diagnostics, :"views/dual-bundlers",
            message: "Multiple JS bundlers configured: #{bundlers.join(', ')}. Pick one.",
            file: "Gemfile"
          )
        end

        if project.spa? && project.importmap? && !project.inertia?
          emit(diagnostics, :"views/spa-with-importmap",
            message: "SPA frontend (React/Vue/etc.) coexists with importmap-rails. importmap is for Hotwire-only apps; remove if your stack is Inertia or a separate SPA build.",
            file: "config/importmap.rb"
          )
        end

        check_resource_partials(diagnostics)
        check_dom_id_string_literals(diagnostics)
        check_stimulus(diagnostics)
        check_api_drift(diagnostics)
      end

      def check_resource_partials(diagnostics)
        return unless project.has_dir?("app/views")
        # For each `app/views/<plural>/index.html.erb`, check that
        # `_<singular>.html.erb` exists in the same directory.
        Dir.glob(project.path("app/views/*/index.html.erb").to_s).each do |index|
          dir = File.dirname(index)
          plural = File.basename(dir)
          singular = plural.sub(/ies$/, "y").sub(/(ses|xes|zes|ches|shes)$/, "").sub(/s$/, "")
          partial = File.join(dir, "_#{singular}.html.erb")
          next if File.exist?(partial)

          source = File.read(index)
          next unless source.match?(/<%\s*@\w+\.each\b/)

          emit(diagnostics, :"views/missing-resource-partial",
            message: "#{relative(index)} loops over a collection inline. Extract `_#{singular}.html.erb` and use `render @#{plural}`.",
            file: relative(index)
          )
        end
      end

      def check_dom_id_string_literals(diagnostics)
        return unless project.has_dir?("app/views")
        Dir.glob(project.path("app/views/**/*.erb").to_s).each do |file|
          File.foreach(file).with_index(1) do |line, lineno|
            if line.match?(/id="[a-z]+_<%=\s*\w+\.id\s*%>"/)
              emit(diagnostics, :"views/dom-id-string-literal",
                message: "Hand-built DOM id string. Use `dom_id(record)` so Turbo broadcasts and partials match automatically.",
                file: relative(file),
                line: lineno
              )
            end
          end
        end
      end

      def check_stimulus(diagnostics)
        dir = project.path("app/javascript/controllers")
        return unless dir.directory?
        Dir.glob(dir.join("**/*.js").to_s).each do |file|
          basename = File.basename(file)
          unless basename.end_with?("_controller.js") || basename == "index.js" || basename == "application.js"
            emit(diagnostics, :"stimulus/file-naming",
              message: "#{basename} doesn't end in `_controller.js`. Stimulus expects this convention to wire up controllers.",
              file: relative(file)
            )
          end

          loc = File.read(file).each_line.count { |l| l.strip != "" && !l.strip.start_with?("//") }
          if loc > 300
            emit(diagnostics, :"stimulus/oversized",
              message: "#{basename} is #{loc} LOC. Stimulus controllers should be small and single-purpose — split.",
              file: relative(file)
            )
          end
        end
      end

      def check_api_drift(diagnostics)
        # Heuristic: a controller has both Jbuilder views (.json.jbuilder) AND
        # ERB views in the same directory but is not under Api::*. Suggests an
        # API got bolted onto an HTML controller. (37signals strongly prefer
        # separating these into Api::* controllers.)
        return unless project.has_dir?("app/views")
        Dir.glob(project.path("app/views/**/*.json.jbuilder").to_s).each do |jbuilder|
          dir = File.dirname(jbuilder)
          next if dir.include?("/api/")
          next unless Dir.glob(File.join(dir, "*.html.erb")).any?
          emit(diagnostics, :"views/api-and-html-controllers",
            message: "Jbuilder view #{relative(jbuilder)} sits next to HTML views. Move JSON endpoints under `app/controllers/api/` and `app/views/api/`.",
            file: relative(jbuilder)
          )
        end
      end
    end
  end
end
