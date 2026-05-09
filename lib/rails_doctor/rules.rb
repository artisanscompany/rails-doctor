# frozen_string_literal: true

# Central rule registry. Every diagnostic emitted by an analyzer or wrapper
# must reference a rule defined here.

module RailsDoctor
  R = Registry

  # ─── Architecture ─────────────────────────────────────────────────────────
  R.define :"arch/service-objects",
    title: "Service-object directory detected",
    category: :architecture,
    default_severity: :warning,
    fix: "Move the behavior onto the model or into a model concern (`app/models/<model>/<trait>.rb`). Reach for a service class only at hard external boundaries (third-party APIs, gateways).",
    doc_url: "https://dev.37signals.com/vanilla-rails-is-plenty/"

  R.define :"arch/policy-directory",
    title: "Policy directory detected (Pundit-style)",
    category: :architecture,
    default_severity: :info,
    fix: "Inline simple authorization checks into controllers via `head :forbidden unless Current.user.can_administer?` or controller concerns. If you keep Pundit, add `allow: [pundit]` to .rails-doctor.yml."

  R.define :"arch/extra-layers",
    title: "Extra architectural layer directory detected",
    category: :architecture,
    default_severity: :warning,
    fix: "Push the behavior into models, concerns, or namespaced controllers. Vanilla Rails has shipped at scale (Basecamp 4: 400 controllers, 500 models, no service layer).",
    doc_url: "https://dev.37signals.com/vanilla-rails-is-plenty/"

  R.define :"arch/hexagonal-layout",
    title: "Hexagonal/clean-arch directory layout in app/",
    category: :architecture,
    default_severity: :warning,
    fix: "Use the stock Rails layout (`app/{controllers,models,views,jobs,helpers}`). Rails apps fare better when you trust the framework's organization."

  R.define :"arch/concerns-deep-dir",
    title: "Concerns nested under app/models/concerns/<model>/",
    category: :architecture,
    default_severity: :info,
    fix: "Move them to `app/models/<model>/<trait>.rb` and namespace as `module Model::Trait`. This is the 37signals signature concern layout.",
    doc_url: "https://dev.37signals.com/good-concerns/"

  # ─── Omakase Gemfile ──────────────────────────────────────────────────────
  R.define :"omakase/banned-gem",
    title: "Banned gem in Gemfile",
    category: :omakase,
    default_severity: :warning,
    fix: "Replace with the Rails default, or add `allow: [<token>]` to .rails-doctor.yml to silence."

  R.define :"omakase/missing-gem",
    title: "Recommended omakase gem missing",
    category: :omakase,
    default_severity: :info,
    fix: "Add the gem to the Gemfile if it fits your stack."

  R.define :"omakase/dual-stack",
    title: "Conflicting gems present",
    category: :omakase,
    default_severity: :error,
    fix: "Remove one of the conflicting gems. They serve the same purpose and shipping both increases dependency surface and confusion."

  R.define :"omakase/test-framework-conflict",
    title: "Both Minitest and RSpec present",
    category: :omakase,
    default_severity: :warning,
    fix: "Pick one framework and delete the other. Running both is fragile."

  R.define :"omakase/factories-with-fixtures",
    title: "factory_bot in Gemfile but no factories",
    category: :omakase,
    default_severity: :info,
    fix: "Either remove `factory_bot_rails` (if you use fixtures) or create `test/factories/`. A dangling test gem confuses future contributors."

  # ─── Models / concerns ────────────────────────────────────────────────────
  R.define :"models/concern-too-large",
    title: "Concern exceeds size threshold",
    category: :models,
    default_severity: :warning,
    fix: "Split the concern into smaller traits or fold it back into the model. A concern names one capability — if it's grown, that's two capabilities.",
    doc_url: "https://dev.37signals.com/good-concerns/"

  R.define :"models/concern-too-small",
    title: "Concern is trivially small",
    category: :models,
    default_severity: :info,
    fix: "Inline the concern back into the model. Premature abstraction adds files without paying for itself."

  R.define :"models/concern-bad-name",
    title: "Concern is not named as a trait",
    category: :models,
    default_severity: :info,
    fix: "Rename to a trait or capability (Searchable, Bannable, Mentionable, Publishable). Generic names (Helpers, Utils, Methods) signal a dumping ground."

  R.define :"models/anemic-model",
    title: "Model has only associations and validations",
    category: :models,
    default_severity: :info,
    fix: "Add domain methods that capture the model's behavior. Active Record models are designed to hold persistence and logic together."

  R.define :"models/fat-model",
    title: "Model exceeds size threshold",
    category: :models,
    default_severity: :warning,
    fix: "Extract per-model concerns under `app/models/<model>/<trait>.rb`. Each concern names a single trait (e.g. `Mentionable`, `Searchable`, `Boostable`)."

  R.define :"models/callback-overuse",
    title: "Model declares many callbacks",
    category: :models,
    default_severity: :info,
    fix: "Move work into named methods or extract a concern. 37signals defends callbacks for orthogonal/auxiliary concerns, but heavy callback chains are usually orchestrating a flow that wants its own object.",
    doc_url: "https://dev.37signals.com/globals-callbacks-and-other-sacrileges/"

  R.define :"models/uniqueness-without-index",
    title: "Uniqueness validation without DB unique index",
    category: :models,
    default_severity: :warning,
    fix: "Add a migration: `add_index :<table>, :<column>, unique: true`. Validations alone race under concurrent inserts."

  R.define :"models/missing-presence-validation",
    title: "Non-nullable column without presence validation",
    category: :models,
    default_severity: :info,
    fix: "Add `validates :<column>, presence: true` so users see a friendly error instead of a 500."

  R.define :"models/use-bang-methods",
    title: "Prefer create!/update! over check-and-render",
    category: :models,
    default_severity: :info,
    fix: "Use `update!` and rescue `ActiveRecord::RecordInvalid` once at the controller level — clearer than `if @x.save; ...; else render :new; end`."

  R.define :"performance/pluck-over-map",
    title: "Use .pluck(:attr) instead of .map(&:attr)",
    category: :performance,
    default_severity: :info,
    fix: "Replace `.map(&:attr)` with `.pluck(:attr)` to avoid instantiating Active Record objects you immediately discard."

  # ─── Controllers ──────────────────────────────────────────────────────────
  R.define :"controllers/non-restful-action",
    title: "Non-RESTful public action",
    category: :controllers,
    default_severity: :warning,
    fix: "Extract the action into a namespaced controller with one of the seven RESTful verbs. Example: `PostsController#publish` becomes `Posts::PublicationsController#create`.",
    doc_url: "https://jeromedalbert.com/how-dhh-organizes-his-rails-controllers/"

  R.define :"controllers/fat-controller",
    title: "Controller exceeds size threshold",
    category: :controllers,
    default_severity: :warning,
    fix: "Push behavior down to models or up into namespaced sub-controllers. A fat controller usually has 2–3 sub-resources hiding inside it."

  R.define :"controllers/heavy-application-controller",
    title: "ApplicationController has too many responsibilities",
    category: :controllers,
    default_severity: :info,
    fix: "Move responsibilities into controller concerns under `app/controllers/concerns/` (e.g. `Authentication`, `RoomScoped`, `SetCurrentRequest`)."

  R.define :"controllers/before-action-overuse",
    title: "Excessive before_action filters",
    category: :controllers,
    default_severity: :info,
    fix: "Consolidate filters or move logic into the action. Many filters hide what an action actually does."

  R.define :"controllers/respond-to-empty-block",
    title: "Empty respond_to format block",
    category: :controllers,
    default_severity: :info,
    fix: "Drop the empty `format.html { render }` — Rails renders by default. Reserve respond_to for actual format branching."

  # ─── Routes ───────────────────────────────────────────────────────────────
  R.define :"routes/non-restful",
    title: "Non-RESTful route declaration",
    category: :routes,
    default_severity: :warning,
    fix: "Extract to a noun resource. Example: `member do; post :publish; end` becomes `resource :publication, only: %i[create destroy]` — verbs become nouns."

  R.define :"routes/verbs-not-nouns",
    title: "Custom verb route — extract to a noun resource",
    category: :routes,
    default_severity: :info,
    fix: "Convert: `POST /posts/:id/publish` → `resource :publication, only: :create` mounted under `resources :posts`. Each state change becomes a record."

  # ─── Migrations / DB ──────────────────────────────────────────────────────
  R.define :"db/missing-fk-index",
    title: "Foreign key without an index",
    category: :database,
    default_severity: :warning,
    fix: "Add `index: true` to the `add_reference` call, or backfill with `add_index :<table>, :<col>_id`."

  R.define :"db/missing-not-null",
    title: "Column without explicit null setting",
    category: :database,
    default_severity: :info,
    fix: "Add `null: false` (or `null: true` if intentional). Implicit nullability is a common source of bugs."

  R.define :"db/boolean-state-column",
    title: "Boolean state column",
    category: :database,
    default_severity: :info,
    fix: "Replace with a relationship record (e.g. `has_one :publication`) and capture who/when/why. Boolean columns lose audit history.",
    doc_url: "https://dev.37signals.com/relationships-as-records/"

  R.define :"db/foreign-key-without-constraint",
    title: "_id column without a foreign-key constraint",
    category: :database,
    default_severity: :info,
    fix: "Add `foreign_key: true` (or a separate `add_foreign_key`) to prevent orphaned rows."

  R.define :"db/inconsistent-pk-types",
    title: "Mixed primary key types across migrations",
    category: :database,
    default_severity: :info,
    fix: "Pick one PK convention (UUIDs or bigints) and stick to it across the schema."

  R.define :"db/timestamps-without-precision",
    title: "datetime column without explicit precision",
    category: :database,
    default_severity: :info,
    fix: "Use `t.datetime :created_at, precision: 6` to match Rails 7+ defaults; mixed precisions cause subtle ordering bugs."

  # ─── Views / frontend ─────────────────────────────────────────────────────
  R.define :"views/spa-with-importmap",
    title: "SPA frontend coexists with importmap-rails",
    category: :views,
    default_severity: :info,
    fix: "If you're on Inertia/Vite/SPA, remove `importmap-rails` and `bin/importmap`. importmap is only useful for Hotwire-only apps."

  R.define :"views/dual-bundlers",
    title: "Multiple JS bundlers configured",
    category: :views,
    default_severity: :warning,
    fix: "Pick one bundler. Importmap + Vite (or jsbundling-rails) running in parallel ships duplicate code and confuses asset URLs."

  R.define :"views/missing-resource-partial",
    title: "Resource view lacks a `_resource.html.erb` partial",
    category: :views,
    default_severity: :info,
    fix: "Extract the loop body into `_<singular>.html.erb` and call `<%= render @<plural> %>`. The same partial then works for index and Turbo broadcasts."

  R.define :"views/dom-id-string-literal",
    title: "Element id is a string literal",
    category: :views,
    default_severity: :info,
    fix: "Use `dom_id(record)` so Turbo Stream broadcasts target the right element automatically."

  R.define :"views/api-and-html-controllers",
    title: "Jbuilder API endpoints mixed with HTML controllers",
    category: :views,
    default_severity: :info,
    fix: "Move JSON endpoints under `app/controllers/api/` and `app/views/api/` so the HTML and API surfaces evolve independently."

  R.define :"views/view-too-large",
    title: "View template is too large",
    category: :views,
    default_severity: :info,
    fix: "Extract sections into partials. Long views are hard to read and to broadcast as Turbo Streams."

  R.define :"i18n/missing-translation",
    title: "Translation key is referenced but not defined",
    category: :i18n,
    default_severity: :warning,
    fix: "Add the key to config/locales/<lang>.yml or use a different key. Missing translations render as 'translation missing: …' in production."

  R.define :"i18n/unused-translation",
    title: "Translation key is defined but never used",
    category: :i18n,
    default_severity: :info,
    fix: "Remove the key (and its translations) so locale files don't accumulate dead entries."

  R.define :"hotwire/stimulus-mismatched-controller",
    title: "Stimulus controller filename doesn't match its data-controller usage",
    category: :hotwire,
    default_severity: :warning,
    fix: "Stimulus expects `foo_bar_controller.js` ↔ `data-controller=\"foo-bar\"`. Rename one to match."

  R.define :"security/secret-in-code",
    title: "API key, token, or private key found in source",
    category: :security,
    default_severity: :error,
    fix: "Move to Rails encrypted credentials (`bin/rails credentials:edit`) or an env var. Rotate the leaked secret."

  R.define :"security/skip-csrf",
    title: "CSRF verification skipped on a non-API controller",
    category: :security,
    default_severity: :warning,
    fix: "Restrict skip_before_action :verify_authenticity_token to API controllers using token auth, or remove it."

  R.define :"security/permit-all-params",
    title: "params.permit! bypasses strong parameters",
    category: :security,
    default_severity: :error,
    fix: "List the allowed attributes explicitly: `params.require(:foo).permit(:a, :b)`."

  R.define :"security/raw-sql-interpolation",
    title: "SQL string interpolation — possible injection",
    category: :security,
    default_severity: :warning,
    fix: "Use placeholders: `where(\"name = ?\", value)` or named binds `where(\"name = :n\", n: value)`."

  R.define :"models/enum-without-prefix-suffix",
    title: "enum declared without prefix:/suffix:",
    category: :models,
    default_severity: :info,
    fix: "Add `prefix: true` or `suffix: true` so the generated `<value>?` and `<value>!` methods don't collide across enums."

  R.define :"models/serialize-without-coder",
    title: "serialize without explicit coder argument",
    category: :models,
    default_severity: :warning,
    fix: "In Rails 7+ pass an explicit coder: `serialize :foo, coder: JSON` (or YAML for legacy data)."

  R.define :"migrations/null-false-without-default",
    title: "add_column null: false without default — breaks existing rows",
    category: :migrations,
    default_severity: :warning,
    fix: "Either add `default:` or split into two migrations: add the column, backfill values, then change_column_null."

  R.define :"models/has-many-without-dependent",
    title: "has_many without `dependent:` option",
    category: :models,
    default_severity: :info,
    fix: "Decide what happens when the parent is destroyed: dependent: :destroy / :destroy_async / :nullify / :restrict_with_error."

  R.define :"models/scope-as-class-method",
    title: "Scope expressed as `def self.<name>` instead of `scope`",
    category: :models,
    default_severity: :info,
    fix: "Use `scope :name, -> { ... }`. It chains as expected, returns a relation lazily, and is the 37signals convention."

  R.define :"hotwire/turbo-frame-id-naming",
    title: "Turbo frame id is hardcoded instead of derived from a record",
    category: :hotwire,
    default_severity: :info,
    fix: "Use `turbo_frame_tag(record)` so the id stays in sync with `dom_id(record)` for stream broadcasts."

  R.define :"stimulus/file-naming",
    title: "Stimulus controller filename should end in _controller.js",
    category: :views,
    default_severity: :info,
    fix: "Rename to `<name>_controller.js`. Stimulus's autoloader expects this suffix."

  R.define :"stimulus/oversized",
    title: "Stimulus controller exceeds size threshold",
    category: :views,
    default_severity: :info,
    fix: "Split into multiple single-purpose controllers. Stimulus is at its best when each controller does one small thing."

  # ─── Tests ────────────────────────────────────────────────────────────────
  R.define :"tests/spec-and-test-coexist",
    title: "Both test/ and spec/ contain tests",
    category: :tests,
    default_severity: :warning,
    fix: "Pick one framework and migrate the other. Running both is slow and fragile."

  R.define :"tests/missing-test-coverage",
    title: "Module has no corresponding test file",
    category: :tests,
    default_severity: :info,
    fix: "Add a corresponding `*_test.rb` (or `_spec.rb`). New code without tests rots fastest."

  R.define :"tests/url-over-path",
    title: "Tests use *_url instead of *_path",
    category: :tests,
    default_severity: :info,
    fix: "Replace `*_url` helpers with `*_path` in tests. URL helpers force host setup and add noise to failures."

  R.define :"tests/factories-and-fixtures",
    title: "Both factory_bot factories and fixtures exist",
    category: :tests,
    default_severity: :warning,
    fix: "Pick one. Mixing both leads to ordering bugs when fixtures and factories disagree about IDs or associations."

  # ─── Stack consistency ────────────────────────────────────────────────────
  R.define :"stack/sprockets-and-propshaft",
    title: "Both Sprockets and Propshaft installed",
    category: :stack,
    default_severity: :error,
    fix: "Remove `sprockets-rails`. Propshaft is the Rails 8 default and ships fewer moving parts."

  R.define :"stack/missing-mission-control",
    title: "Solid Queue installed without Mission Control",
    category: :stack,
    default_severity: :info,
    fix: "Add `gem 'mission_control-jobs'` and `mount MissionControl::Jobs::Engine, at: '/jobs'` for a web UI over Solid Queue."

  R.define :"stack/vestigial-importmap",
    title: "importmap-rails binstub without config",
    category: :stack,
    default_severity: :info,
    fix: "Delete `bin/importmap`. It's a leftover from a previous stack."

  R.define :"stack/redis-with-solid-cache",
    title: "Redis still in Gemfile alongside solid_cache",
    category: :stack,
    default_severity: :info,
    fix: "If Redis is only for cache/cable, remove it. Keep it only for typed Kredis structures or Action Cable."

  R.define :"stack/devise-and-has-secure-password",
    title: "Devise alongside has_secure_password",
    category: :stack,
    default_severity: :warning,
    fix: "Pick one auth path. Rails 8's `bin/rails generate authentication` covers most cases without Devise."

  R.define :"stack/sti-without-type-index",
    title: "STI table without index on type column",
    category: :stack,
    default_severity: :info,
    fix: "Add `t.index :type` to the table. STI scopes always filter by type — without an index they table-scan."

  # ─── Security / dependencies (from wrappers) ──────────────────────────────
  R.define :"security/brakeman",
    title: "Brakeman finding",
    category: :security,
    default_severity: :error,
    fix: "Read the Brakeman warning and remediate. Common fixes: scope finds with `Current.account`, sanitize HTML inputs, avoid string interpolation in SQL."

  R.define :"security/bundler-audit",
    title: "Vulnerable dependency",
    category: :security,
    default_severity: :error,
    fix: "Update the gem to a patched version. Check the linked advisory for impact."

  R.define :"db/active-record-doctor",
    title: "active_record_doctor finding",
    category: :database,
    default_severity: :warning,
    fix: "Run `bundle exec rails active_record_doctor` for full diagnosis. Common fixes: missing indexes on FKs, missing `validates :foreign_key_id, presence: true`."

  R.define :"style/rubocop",
    title: "RuboCop offense",
    category: :smells,
    default_severity: :info,
    fix: "Run `bundle exec rubocop -A` to autofix. Use `rubocop-rails-omakase` for the 37signals defaults."

  R.define :"smells/reek",
    title: "Reek code smell",
    category: :smells,
    default_severity: :info,
    fix: "See the linked Reek docs for the specific smell. Often resolved by extracting a method or splitting a class."

  R.define :"dead/debride",
    title: "Possibly unused method",
    category: :dead_code,
    default_severity: :info,
    fix: "Confirm with grep / git history, then delete. False positives happen for dynamically-called methods."

  R.define :"dead/traceroute",
    title: "Unused or undefined route action",
    category: :dead_code,
    default_severity: :info,
    fix: "Either delete the route or add the missing action. Traceroute false-positives on concerns that provide actions."
end
