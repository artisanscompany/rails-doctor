# frozen_string_literal: true

module RailsDoctor
  # Auto-detects facts about the Rails project so analyzers can adapt
  # (e.g. don't require Hotwire if the project clearly uses Inertia/React).
  class Project
    attr_reader :root

    def initialize(root)
      @root = Pathname.new(root).expand_path
    end

    def rails_app?
      gemfile? && (path("config/application.rb").exist? || rails_in_gemfile?)
    end

    def gemfile?
      path("Gemfile").exist?
    end

    def gemfile_text
      @gemfile_text ||= path("Gemfile").exist? ? path("Gemfile").read : ""
    end

    def gemfile_lock_text
      @gemfile_lock_text ||= path("Gemfile.lock").exist? ? path("Gemfile.lock").read : ""
    end

    def rails_in_gemfile?
      gemfile_text.match?(/^\s*gem\s+['"]rails['"]/)
    end

    def rails_version
      gemfile_lock_text.match(/^\s+rails \(([\d\.]+)/)&.captures&.first
    end

    def has_gem?(name)
      gemfile_text.match?(/^\s*gem\s+['"]#{Regexp.escape(name)}['"]/)
    end

    def gem_in_lockfile?(name)
      gemfile_lock_text.match?(/^\s+#{Regexp.escape(name)} \(/)
    end

    def has_dir?(relative)
      path(relative).directory?
    end

    def has_file?(relative)
      path(relative).file?
    end

    def path(*parts)
      root.join(*parts)
    end

    def glob(pattern)
      Dir.glob(root.join(pattern).to_s)
    end

    def read(relative)
      p = path(relative)
      p.exist? ? p.read : nil
    end

    # Frontend stack inference
    def hotwire?
      has_gem?("turbo-rails") || has_gem?("stimulus-rails")
    end

    def inertia?
      has_gem?("inertia_rails") || has_file?("app/views/layouts/inertia.html.erb")
    end

    def vite?
      has_gem?("vite_rails") || has_file?("vite.config.ts") || has_file?("vite.config.js")
    end

    def importmap?
      has_gem?("importmap-rails") || has_file?("config/importmap.rb")
    end

    def jsbundling?
      has_gem?("jsbundling-rails")
    end

    def webpacker?
      has_gem?("webpacker") || has_gem?("shakapacker")
    end

    def spa?
      package = read("package.json") || ""
      package.match?(/"react"|"vue"|"@angular\/core"|"svelte"/)
    end

    # Test framework
    def rspec?
      has_gem?("rspec-rails") || has_gem?("rspec") || has_dir?("spec")
    end

    def minitest?
      has_dir?("test") && !rspec?
    end

    # Background jobs
    def solid_queue?
      has_gem?("solid_queue")
    end

    def sidekiq?
      has_gem?("sidekiq")
    end

    # Cache / cable
    def solid_cache?
      has_gem?("solid_cache")
    end

    def solid_cable?
      has_gem?("solid_cable")
    end

    # Asset pipeline
    def propshaft?
      has_gem?("propshaft")
    end

    def sprockets?
      has_gem?("sprockets-rails") || has_gem?("sprockets")
    end

    # Deployment is intentionally not inferred — we don't enforce a deploy stack.

    # Summary used by reporters
    def to_h
      {
        root: root.to_s,
        rails_version: rails_version,
        frontend: detect_frontend,
        test: rspec? ? "rspec" : (minitest? ? "minitest" : "unknown"),
        jobs: solid_queue? ? "solid_queue" : (sidekiq? ? "sidekiq" : "unknown"),
        asset_pipeline: propshaft? ? "propshaft" : (sprockets? ? "sprockets" : "unknown")
      }
    end

    def detect_frontend
      return "inertia" if inertia?
      return "hotwire" if hotwire? && !spa?
      return "spa-react-vue" if spa?
      "unknown"
    end
  end
end
