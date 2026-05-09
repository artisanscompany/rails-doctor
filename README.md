# rails-doctor

> Your agent writes bad Rails. This catches it.

A static-analysis CLI for Ruby on Rails projects that scores your codebase 0–100, flags architecture and convention violations, and installs as an agent skill so Claude Code, Codex, Cursor, and Copilot write better Rails up front.

Codifies 37signals/DHH's Rails philosophy as enforceable rules. Framework-aware: Inertia/SPA stacks aren't penalized for skipping Hotwire, Sidekiq is allowed when configured, and deployment is intentionally not enforced.

## Quick start

```bash
# Run a scan, no install needed
npx -y rails-doctor@latest scan .

# Install as an agent skill so Claude Code / Codex / Cursor write better Rails
npx -y rails-doctor@latest install
```

`npx` runs the bundled Ruby scanner via your system Ruby. **No `gem install` required** — every Rails developer already has Ruby on PATH.

Requirements: Node 18+ and Ruby 3.1+.

## Use

```bash
npx -y rails-doctor@latest scan .                  # TTY output
npx -y rails-doctor@latest scan . --json           # machine-readable
npx -y rails-doctor@latest scan . --markdown       # GitHub PR-comment ready
npx -y rails-doctor@latest scan . --strict         # warnings become errors
npx -y rails-doctor@latest scan . --min-score 75   # exit non-zero below threshold
npx -y rails-doctor@latest scan . --with-external all   # also run brakeman/rubocop/etc.

npx -y rails-doctor@latest explain controllers/non-restful-action
npx -y rails-doctor@latest rules
npx -y rails-doctor@latest install --dry-run       # see which agents would get the skill
```

## What it covers

### First-party rules (no external dependencies)

| Category | Examples |
|---|---|
| **Architecture** | `app/services/`, `app/policies/`, `app/queries/`, hexagonal layouts, deeply-nested concern dirs |
| **Omakase Gemfile** | banned gems (sidekiq, devise, draper, dry-rb, view_component, …) — all opt-out via `allow:`; recommended gems; dual-stack errors |
| **Models / concerns** | concern size 5–150 LOC, trait-style naming, anemic-model detection (AST), fat-model detection, callback overuse, uniqueness-without-index, .pluck-over-.map |
| **Controllers (AST)** | RESTful-only public actions, fat controllers, thin ApplicationController, before_action overuse |
| **Routes** | `member do` / `collection do`, custom verbs (verbs-become-nouns) |
| **Migrations / DB** | foreign-key indexes, foreign-key constraints, boolean state columns, mixed PK types |
| **Views / frontend** | dual bundlers, SPA + importmap drift, missing resource partials, `dom_id` string literals, Stimulus naming and size, API/HTML controller drift |
| **Stack consistency** | sprockets+propshaft, Solid Queue without Mission Control, vestigial importmap, redis+solid_cache, devise+has_secure_password, STI without type index |
| **Tests** | spec/+test/ coexistence, factory_bot+fixtures coexistence, `*_url` over `*_path` |

### Wrapped tools (opt-in, run automatically when in your Gemfile)

| Tool | Purpose |
|---|---|
| [brakeman](https://github.com/presidio-oss/brakeman) | Rails-specific security (SQLi, XSS, mass assignment, open redirect) |
| [bundler-audit](https://github.com/rubysec/bundler-audit) | Vulnerable dependencies |
| [active_record_doctor](https://github.com/gregnavis/active_record_doctor) | Schema findings (missing/unused indexes, orphaned FKs) |
| [rubocop](https://github.com/rubocop/rubocop) | Style and lint |
| [reek](https://github.com/troessner/reek) | Code smells |
| [debride](https://github.com/seattlerb/debride) | Possibly unused methods |
| [traceroute](https://github.com/amatsuda/traceroute) | Unused or undefined route actions |
| [rubycritic](https://github.com/whitesmith/rubycritic) | Aggregate quality grade per file |

## Configuration

Drop a `.rails-doctor.yml` at your project root (full example: `.rails-doctor.yml.example`).

```yaml
preset: default          # default | strict | omakase | minimal
allow:
  - sidekiq              # we use Sidekiq, don't suggest Solid Queue
  - inertia-react        # frontend uses Inertia (auto-detected too)
  - rspec
  - services             # we keep app/services for external API adapters
disable:
  - controllers/non-restful-action
severity:
  models/concern-too-large: error
thresholds:
  concern_max_loc: 150
  controller_max_loc: 200
  model_max_loc: 400
external:
  enabled: true
  tools: [brakeman, bundler-audit, active_record_doctor]
```

## Scoring

Severity-weighted (error=5, warning=2, info=0.5), per-rule cap of 20 points so one noisy rule cannot dominate, then `100 − total deductions`.

| Score | Grade |
|---|---|
| 75+ | Great |
| 50–74 | Needs work |
| < 50 | Critical |

## Agent skill installation

```bash
npx -y rails-doctor@latest install              # installs skill for detected agents
npx -y rails-doctor@latest install --dry-run    # show what would be installed
npx -y rails-doctor@latest install --yes        # install for all without prompting
```

Detected: Claude Code (`~/.claude/skills/`), Codex (`~/.agents/skills/`), Cursor (`~/.cursor/skills/`), Windsurf, GitHub Copilot, OpenCode.

The skill teaches your agent the same rules rails-doctor enforces, so it writes correct Rails on the way in instead of being corrected after the fact.

## GitHub Action

```yaml
# .github/workflows/rails-doctor.yml
name: rails-doctor
on: [pull_request, push]
permissions:
  contents: read
  pull-requests: write
jobs:
  rails-doctor:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: artisanscompany/rails-doctor@v0
        with:
          min-score: "75"
          comment-on-pr: "true"
```

The action posts a Markdown summary as a PR comment (updated in place on each push) and fails the build below `min-score`.

## Deployment is intentionally not enforced

Kamal, Heroku, Fly, Render, Capistrano, Docker, Kubernetes — all fine. We score code, not your Procfile.

## Philosophy

rails-doctor is opinionated about *Rails code*: routes, controllers, models, concerns, migrations, the Gemfile. It's lenient about *infrastructure choices* (deployment, multi-DB, queue backend, frontend stack) because those are project-level decisions that don't have a single right answer.

The default preset reflects 37signals/DHH conventions. If your team has chosen differently — Sidekiq instead of Solid Queue, RSpec instead of Minitest, Inertia instead of Hotwire — set `allow:` tokens in your config and rails-doctor will respect them.

## Distribution

Distributed as an [npm package](https://www.npmjs.com/package/rails-doctor). The package bundles the Ruby scanner source and a small Node wrapper that shells out to your system Ruby. No gem install, no Gemfile changes, no Bundler cache invalidation. Zero npm runtime deps; zero gem runtime deps (Ruby stdlib + built-in Prism).

## License

MIT. Built by [ArtisansCompany](https://artisanscompany.dev).
