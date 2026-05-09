# frozen_string_literal: true

module RailsDoctor
  module Analyzers
    class Architecture < Base
      EXTRA_LAYERS = {
        "app/services"     => :"arch/service-objects",
        "app/policies"     => :"arch/policy-directory",
        "app/queries"      => :"arch/extra-layers",
        "app/forms"        => :"arch/extra-layers",
        "app/operations"   => :"arch/extra-layers",
        "app/interactors"  => :"arch/extra-layers",
        "app/use_cases"    => :"arch/extra-layers",
        "app/decorators"   => :"arch/extra-layers",
        "app/presenters"   => :"arch/extra-layers",
        "app/contracts"    => :"arch/extra-layers"
      }.freeze

      HEXAGONAL = %w[app/domain app/application app/infrastructure app/adapters].freeze

      private

      def analyze(diagnostics)
        EXTRA_LAYERS.each do |dir, rule|
          next unless project.has_dir?(dir)
          count = project.glob("#{dir}/**/*.rb").size
          next if count.zero?
          next if rule == :"arch/policy-directory" && allowed?("pundit")
          next if rule == :"arch/service-objects" && allowed?("services")

          emit(diagnostics, rule,
            message: "#{dir} contains #{count} files. 37signals/Vanilla Rails prefers fitting this behavior into models, concerns, or namespaced controllers.",
            file: dir
          )
        end

        if HEXAGONAL.any? { |d| project.has_dir?(d) }
          emit(diagnostics, :"arch/hexagonal-layout",
            message: "Hexagonal/clean-arch directories detected in app/. Rails apps usually fare better with the stock layout.",
            file: "app/"
          )
        end

        # app/models/concerns/<model>/ pattern (deeper than 1 level into concerns/)
        if project.has_dir?("app/models/concerns")
          Dir.glob(project.path("app/models/concerns/*/").to_s).each do |dir|
            inner = Dir.glob(File.join(dir, "*.rb"))
            next if inner.empty?
            emit(diagnostics, :"arch/concerns-deep-dir",
              message: "Concerns nested under `app/models/concerns/#{File.basename(dir)}/`. Move them to `app/models/#{File.basename(dir)}/` and namespace as `module #{File.basename(dir).capitalize}::Trait`.",
              file: relative(dir)
            )
          end
        end
      end
    end
  end
end
