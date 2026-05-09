---
name: rails-doctor
description: Use when writing, reviewing, or refactoring Ruby on Rails code. Codifies 37signals/DHH conventions, the Rails Doctrine, and integrates wrappers around Brakeman, RuboCop, RubyCritic, active_record_doctor, bundler-audit, debride, and traceroute. Run `rails-doctor scan .` before committing or when the user asks for a Rails health check.
---

# rails-doctor

Static-analysis CLI for Rails that scores a codebase 0–100 and flags architecture, convention, security, and dead-code issues. Designed around 37signals' Rails philosophy but framework-aware: Inertia/SPA stacks are not flagged for missing Hotwire, Sidekiq is allowed when explicitly configured, etc.

## When to use

- The user asks for a Rails health check, audit, or score.
- Before committing Rails code (analogous to react-doctor for React).
- When refactoring controllers, models, or routes.
- When a PR touches `Gemfile`, `config/routes.rb`, or `app/{controllers,models,views,jobs}/`.

## Invocation

```bash
rails-doctor scan .                  # full scan, TTY output
rails-doctor scan . --json           # machine-readable
rails-doctor scan . --markdown       # GitHub PR-comment ready
rails-doctor scan . --strict         # warnings become errors
rails-doctor scan . --min-score 75   # exit non-zero if below threshold
rails-doctor explain controllers/non-restful-action
rails-doctor rules
```

If `rails-doctor` isn't on PATH:

```bash
gem exec rails-doctor scan .
# or add to Gemfile :development group: gem "rails-doctor"
```

## What it checks

### Architecture
- `app/services/`, `app/policies/`, `app/queries/`, `app/forms/`, `app/operations/`, `app/interactors/`, `app/decorators/`, `app/presenters/` flagged. Vanilla Rails fits this behavior into models, concerns, or namespaced controllers.
- Hexagonal layouts (`app/domain`, `app/application`, `app/infrastructure`) flagged.

### Gemfile (omakase)
- **Banned (with `allow:` opt-out)**: sidekiq, delayed_job, resque, devise, draper, trailblazer, interactor, dry-rb stack, view_component, simple_form, slim/haml, kaminari, will_paginate.
- **Recommended**: propshaft, bootsnap, brakeman, rubocop-rails-omakase.
- **Dual-stack errors**: sidekiq+solid_queue, sprockets+propshaft, webpacker+propshaft.
- **Test-framework conflict**: both spec/ and test/ contain tests.
- **factory_bot dangling**: gem present but no factories directory.

### Models & concerns
- Concern size: 5–150 LOC by default.
- Concern naming: trait-style (`Searchable`, `Bannable`, `Mentionable`); flag generic names (`Helpers`, `Utils`, `Methods`).
- Anemic-model detection: associations + validations but zero instance methods.
- Fat-model detection: model > 400 LOC.

### Controllers
- Only the seven RESTful actions (index/show/new/create/edit/update/destroy). Custom actions get extracted to namespaced controllers (e.g. `Posts::PublicationsController#create` instead of `PostsController#publish`).
- Fat-controller detection: > 200 LOC.
- ApplicationController kept thin: < 30 LOC, ≤ 4 before_actions.

### Routes
- `member do` / `collection do` flagged.
- "Verbs become nouns": `POST /posts/:id/publish` should be `resource :publication, only: :create`.

### Migrations / DB
- Foreign-key columns without an explicit index.
- Boolean state columns (`archived`, `published`, `closed`, etc.) — recommend modeling as a relationship record.

### Views & frontend (framework-aware)
- Multiple JS bundlers configured (importmap + jsbundling + vite).
- SPA framework + importmap-rails coexisting (importmap is for Hotwire-only stacks).
- Framework auto-detected from Gemfile and `package.json` so Inertia/React/Vue projects are not penalized for skipping Hotwire.

### Stack consistency
- Sprockets and Propshaft both installed.
- Solid Queue installed but mission_control-jobs missing.
- Vestigial `bin/importmap` binstub from a previous stack.

### Tests
- Both `test/` and `spec/` contain tests.
- Optional coverage hooks (off by default).

### External tool wrappers (opt-in, off by default unless gem is in user's Gemfile)
- `brakeman` — Rails-specific security (SQLi, XSS, mass assignment, open redirect).
- `bundler-audit` — vulnerable dependencies.
- `active_record_doctor` — schema findings (missing indexes, orphaned FKs, etc.).
- `rubocop` — style and lint (paired well with `rubocop-rails-omakase`).
- `reek` — code smells.
- `debride` — possibly unused methods.
- `traceroute` — unused or undefined route actions.
- `rubycritic` — aggregate quality grade per file.

## Configuration

Drop a `.rails-doctor.yml` at the project root:

```yaml
preset: default          # default | strict | omakase | minimal
allow:
  - sidekiq              # allow Sidekiq alongside other choices
  - inertia-react        # silence Hotwire-related rules (also auto-detected)
  - rspec
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

## Deployment is not enforced

rails-doctor is intentionally opinion-free about deployment. Kamal, Heroku, Fly.io, Render, Capistrano, Docker Swarm, Kubernetes — all fine. We don't gate on `config/deploy.yml`.

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

Run `rails-doctor explain <rule-id>` for any rule. The full rule catalog is at https://github.com/artisanscompany/rails-doctor.
