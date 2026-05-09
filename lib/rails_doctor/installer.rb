# frozen_string_literal: true

require "fileutils"

module RailsDoctor
  # Drops a SKILL.md into each detected coding agent's skills dir.
  # Detection is path-based so it works without any of the agents being open.
  class Installer
    AGENTS = [
      { name: "Claude Code",     path: "~/.claude/skills/rails-doctor" },
      { name: "Codex",           path: "~/.agents/skills/rails-doctor" },
      { name: "Cursor",          path: "~/.cursor/skills/rails-doctor" },
      { name: "Windsurf",        path: "~/.codeium/windsurf/skills/rails-doctor" },
      { name: "GitHub Copilot",  path: "~/.config/github-copilot/skills/rails-doctor" },
      { name: "OpenCode",        path: "~/.config/opencode/skills/rails-doctor" }
    ].freeze

    def initialize(dry_run: false, yes: false)
      @dry_run = dry_run
      @yes = yes
    end

    def run
      detected = AGENTS.select { |a| parent_dir_exists?(a[:path]) }

      if detected.empty?
        puts "rails-doctor: no supported coding agent directories detected."
        puts "Looked for: #{AGENTS.map { |a| a[:path] }.join(', ')}"
        return
      end

      if @dry_run
        puts "Dry run — would install rails-doctor skill for:"
        detected.each { |a| puts "  - #{a[:name]} (#{a[:path]})" }
        puts "Source: #{skill_source}"
        return
      end

      detected.each { |a| install_for(a) }
      puts "rails-doctor skill installed for #{detected.map { |a| a[:name] }.join(', ')}."
    end

    private

    def parent_dir_exists?(path)
      File.directory?(File.expand_path(File.dirname(path)))
    end

    def install_for(agent)
      target_dir = File.expand_path(agent[:path])
      FileUtils.mkdir_p(target_dir)
      FileUtils.cp(skill_source, File.join(target_dir, "SKILL.md"))
    end

    def skill_source
      File.expand_path(File.join(__dir__, "..", "..", "skills", "rails-doctor", "SKILL.md"))
    end
  end
end
