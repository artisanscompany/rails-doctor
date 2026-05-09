# frozen_string_literal: true

module RailsDoctor
  module Analyzers
    class Gemfile < Base
      # Gems that signal a divergence from Rails defaults. Each is paired with
      # an `allow:` token so projects can opt out (e.g. `allow: [sidekiq]`).
      BANNED = {
        "sidekiq"            => { allow: "sidekiq",       rationale: "Solid Queue is the Rails 8 default." },
        "delayed_job"        => { allow: "delayed_job",   rationale: "Use Active Job + Solid Queue or your existing adapter." },
        "resque"             => { allow: "resque",        rationale: "Solid Queue is the Rails 8 default." },
        "devise"             => { allow: "devise",        rationale: "Rails 8 ships native auth (`bin/rails generate authentication`)." },
        "draper"             => { allow: "draper",        rationale: "Helpers + plain methods cover this." },
        "active_decorator"   => { allow: "draper",        rationale: "Helpers + plain methods cover this." },
        "trailblazer"        => { allow: "trailblazer",   rationale: "Vanilla Rails is plenty." },
        "interactor"         => { allow: "interactor",    rationale: "Vanilla Rails is plenty." },
        "dry-monads"         => { allow: "dry",           rationale: "dry-rb stack is rejected by 37signals — keep Ruby idiomatic." },
        "dry-validation"     => { allow: "dry",           rationale: "Use Active Model validations." },
        "dry-struct"         => { allow: "dry",           rationale: "Use plain Ruby classes or Data.define." },
        "dry-types"          => { allow: "dry",           rationale: "dry-rb stack is rejected by 37signals." },
        "dry-transaction"    => { allow: "dry",           rationale: "dry-rb stack is rejected by 37signals." },
        "view_component"     => { allow: "view_component", rationale: "Plain partials + helpers are the omakase choice." },
        "simple_form"        => { allow: "simple_form",   rationale: "form_with is the omakase choice." },
        "slim-rails"         => { allow: "slim",          rationale: "ERB is the omakase choice." },
        "haml-rails"         => { allow: "haml",          rationale: "ERB is the omakase choice." },
        "kaminari"           => { allow: "kaminari",      rationale: "geared_pagination or hand-rolled is plenty." },
        "will_paginate"      => { allow: "will_paginate", rationale: "geared_pagination or hand-rolled is plenty." }
      }.freeze

      RECOMMENDED = %w[
        propshaft
        bootsnap
        brakeman
        rubocop-rails-omakase
      ].freeze

      DUAL_STACK = [
        { gems: %w[sidekiq solid_queue],     msg: "Both Sidekiq and Solid Queue installed. Pick one queue backend." },
        { gems: %w[sprockets-rails propshaft], msg: "Both Sprockets and Propshaft installed. Pick one asset pipeline." },
        { gems: %w[webpacker propshaft],     msg: "Webpacker and Propshaft both present. Webpacker is retired." }
      ].freeze

      private

      def analyze(diagnostics)
        return unless project.gemfile?

        BANNED.each do |gem, meta|
          next unless project.has_gem?(gem)
          next if allowed?(meta[:allow])

          emit(diagnostics, :"omakase/banned-gem",
            message: "Gemfile lists `#{gem}`. #{meta[:rationale]} Add `allow: [#{meta[:allow]}]` to .rails-doctor.yml to silence.",
            file: "Gemfile"
          )
        end

        RECOMMENDED.each do |gem|
          next if project.has_gem?(gem)
          emit(diagnostics, :"omakase/missing-gem",
            message: "Recommended gem `#{gem}` is not in the Gemfile.",
            file: "Gemfile"
          )
        end

        DUAL_STACK.each do |entry|
          next unless entry[:gems].all? { |g| project.has_gem?(g) }
          emit(diagnostics, :"omakase/dual-stack", message: entry[:msg], file: "Gemfile")
        end

        if project.rspec? && project.has_dir?("test") && Dir.glob(project.path("test/**/*_test.rb").to_s).any?
          emit(diagnostics, :"omakase/test-framework-conflict",
            message: "Both spec/ and test/ are present. Pick one framework.",
            file: "Gemfile"
          )
        end

        if project.has_gem?("factory_bot_rails")
          factories_dir = project.path("test/factories")
          spec_factories = project.path("spec/factories")
          factories_present = (factories_dir.directory? && Dir.children(factories_dir).any?) ||
                              (spec_factories.directory? && Dir.children(spec_factories).any?)
          unless factories_present
            emit(diagnostics, :"omakase/factories-with-fixtures",
              message: "factory_bot_rails is in the Gemfile but no factories directory exists. Either remove the gem or add factories — fixtures-only projects shouldn't ship the dependency.",
              file: "Gemfile"
            )
          end
        end
      end
    end
  end
end
