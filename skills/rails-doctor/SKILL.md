---
name: rails-doctor
description: Use when finishing a feature, fixing a bug, before committing Rails code, or when the user wants a Rails health check. Checks for score regression. Covers architecture, RESTful conventions, models/concerns, migrations, omakase Gemfile, and integrates Brakeman + bundler-audit + active_record_doctor + RuboCop + Reek + debride + traceroute + RubyCritic when present.
version: "1.0.0"
---

# Rails Doctor

Scans Ruby on Rails codebases for architecture, convention, security, schema, dead-code, and style issues. Outputs a 0–100 health score. Codifies 37signals/DHH conventions and the Rails Doctrine, with framework auto-detection so Inertia/SPA stacks aren't penalized for skipping Hotwire and stack choices like Sidekiq are opt-in via config.

## After making Rails code changes:

Run `npx -y rails-doctor@latest scan . --verbose --diff` and check the score did not regress.

If the score dropped, fix the regressions before committing.

## For general cleanup or code improvement:

Run `npx -y rails-doctor@latest scan . --verbose` (without `--diff`) to scan the full codebase. Fix issues by severity — errors first, then warnings.

## Command

```bash
npx -y rails-doctor@latest scan . --verbose --diff
```

| Flag | Purpose |
|---|---|
| `.` | Scan current directory |
| `--verbose` | Show all rules and full file lists |
| `--diff [BASE]` | Only scan files changed vs base branch (defaults to `main`) |
| `--score` | Output only the numeric score (for CI gates) |
| `--strict` | Promote warnings to errors |
| `--full` | Show all categories without truncation |
| `--json` | Machine-readable output |
| `--markdown` | GitHub PR-comment ready output |
| `--with-external auto\|all\|off` | Run wrapped tools (brakeman, rubocop, etc.) |
| `--fail-on error\|warning\|none` | Exit non-zero policy |
| `--min-score N` | Exit non-zero if score < N |

## Distribution

**Distributed via npm — NOT a Ruby gem.** Do not try `gem install rails-doctor` or `bundle exec rails-doctor`. Use:

```bash
npx -y rails-doctor@latest scan .
```

This works on any machine with Node 18+ and Ruby 3.1+ on PATH. The Node wrapper shells out to your system Ruby — no `bundle install`, no Gemfile changes, no gem install required.

## What it covers (built-in)

- **Architecture** — `app/services/`, `app/policies/`, `app/queries/`, `app/decorators/`, hexagonal layouts, deeply-nested concern dirs.
- **Omakase Gemfile** — banned gems (sidekiq, devise, draper, dry-rb, view_component, kaminari, …) all opt-out via `allow:`; recommended gems; dual-stack (sidekiq+solid_queue, sprockets+propshaft, …).
- **Models / concerns** — concern size 5–150 LOC, trait-style naming, anemic-model detection (AST), fat-model detection, callback overuse, uniqueness-without-index, `.pluck` over `.map`.
- **Controllers (AST)** — only the seven RESTful actions, fat controllers, thin ApplicationController, before_action overuse.
- **Routes** — `member do` / `collection do`, custom verbs (verbs-become-nouns).
- **Migrations / DB** — foreign-key indexes, foreign-key constraints, boolean state columns, mixed PK types.
- **Views & Stimulus** — dual bundlers, SPA + importmap drift, missing resource partials, `dom_id` string literals, Stimulus naming and size, API/HTML controller drift.
- **Stack consistency** — sprockets+propshaft, Solid Queue without Mission Control, vestigial importmap, redis+solid_cache, devise+has_secure_password, STI without type index.
- **Tests** — spec/+test/ coexistence, factory_bot+fixtures coexistence, `*_url`-over-`*_path`.

## Wrapped tools (opt-in, run automatically when in your Gemfile)

For full coverage, the user can add these to their Rails project's Gemfile under `:development, :test`:

```ruby
gem "brakeman",             require: false   # security
gem "bundler-audit",        require: false   # vulnerable dependencies
gem "active_record_doctor", require: false   # schema findings
gem "rubocop-rails-omakase", require: false  # style (37signals defaults)
gem "reek",                 require: false   # code smells
gem "debride",              require: false   # dead methods
gem "traceroute",           require: false   # unused routes
gem "rubycritic",           require: false   # aggregate quality grade
```

rails-doctor automatically detects which are installed and runs them. They are **all optional** — rails-doctor still produces a useful score with none of them. With `--with-external all`, rails-doctor will try to run any tool whose binary is on PATH.

## Configuration

Drop a `.rails-doctor.yml` at the project root:

```yaml
preset: default          # default | strict | omakase | minimal
allow:
  - sidekiq              # we use Sidekiq
  - inertia-react        # frontend uses Inertia (auto-detected)
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

| Score | Grade |
|---|---|
| 75+ | Great |
| 50–74 | Needs work |
| < 50 | Critical |

Scoring is **per-unique-rule** (matching react-doctor):
- Each unique error rule deducts 1.5 points.
- Each unique warning rule deducts 0.75 points.
- One rule firing 100 times still only deducts once — score reflects how *diverse* the breakage is, not how many findings exist.

## Deployment is intentionally not enforced

Kamal, Heroku, Fly, Render, Capistrano, Docker, Kubernetes — all fine. We score code, not your Procfile.

## When to use

- The user asks for a Rails health check, audit, or score.
- After a feature, before committing — run with `--diff` to check for regression.
- When refactoring controllers, models, or routes.
- When a PR touches `Gemfile`, `config/routes.rb`, or `app/{controllers,models,views,jobs}/`.

## Coding guidance for agents (apply when writing new Rails code)

When generating Rails code, default to these patterns unless the project's `.rails-doctor.yml` or existing code says otherwise:

1. **Routes are RESTful.** Map every action to one of the seven CRUD verbs. When something doesn't fit, create a new resource — verbs become nouns: `approve` → `Approval`, `publish` → `Publication`, `archive` → `Archive`.
2. **Concerns are traits.** Name them `-able`/`-er`/`-ee` or as a domain noun. Keep them 5–150 LOC and single-responsibility. Prefer `app/models/<model>/<trait>.rb` over a flat `app/models/concerns/`.
3. **Active Record is rich.** Methods belong on the model, not in a separate service object. Reach for a service class only at hard external boundaries (third-party APIs, gateways).
4. **State as records, not booleans.** Replace `closed: boolean` with `has_one :closure`. Capture who/when/why.
5. **Default values via `Current`.** `belongs_to :creator, class_name: "User", default: -> { Current.user }` over passing `current_user` through method args.
6. **Bang methods for state changes.** `update!`, `create!` — let invariants raise.
7. **Validations and DB constraints in lockstep.** Every uniqueness validation also gets a unique DB index. Every `null: false` migration column also has model presence validation when user-facing.
8. **Active Job, not direct Sidekiq workers.** `class WelcomeJob < ApplicationJob`.
9. **Minitest + fixtures**, unless the project has chosen RSpec (detected via `spec/`). Don't introduce factory_bot if fixtures exist.
10. **Hotwire by default for new views**, unless the project is detected as Inertia/SPA — in which case match the existing stack.
11. **Stay vanilla.** Don't add new directories under `app/` (services, policies, decorators, etc.) without an explicit reason; offer the rich-model alternative first.

## Reference

Run `npx -y rails-doctor@latest explain <rule-id>` for any rule. Full rule catalog: `npx -y rails-doctor@latest rules`. Source: https://github.com/artisanscompany/rails-doctor.
