# frozen_string_literal: true

# Central rule registry. Every diagnostic emitted by an analyzer or wrapper
# must reference a rule defined here. Adding a rule is a one-liner.

module RailsDoctor
  R = Registry

  # Architecture
  R.define :"arch/service-objects",
    title: "Service-object directory detected",
    category: :architecture,
    default_severity: :warning,
    doc_url: "https://dev.37signals.com/vanilla-rails-is-plenty/"

  R.define :"arch/policy-directory",
    title: "Policy directory detected (Pundit-style)",
    category: :architecture,
    default_severity: :info

  R.define :"arch/extra-layers",
    title: "Extra architectural layer directory detected (queries/forms/operations/interactors/decorators/presenters)",
    category: :architecture,
    default_severity: :warning,
    doc_url: "https://dev.37signals.com/vanilla-rails-is-plenty/"

  R.define :"arch/hexagonal-layout",
    title: "Hexagonal/clean-arch directory layout in app/",
    category: :architecture,
    default_severity: :warning

  # Omakase Gemfile
  R.define :"omakase/banned-gem",
    title: "Banned gem in Gemfile (replaceable by Rails defaults)",
    category: :omakase,
    default_severity: :warning

  R.define :"omakase/missing-gem",
    title: "Recommended omakase gem missing",
    category: :omakase,
    default_severity: :info

  R.define :"omakase/dual-stack",
    title: "Conflicting gems present (e.g. sidekiq + solid_queue, sprockets + propshaft)",
    category: :omakase,
    default_severity: :error

  R.define :"omakase/test-framework-conflict",
    title: "Both Minitest and RSpec present",
    category: :omakase,
    default_severity: :warning

  R.define :"omakase/factories-with-fixtures",
    title: "factory_bot in Gemfile but test/factories/ missing or empty",
    category: :omakase,
    default_severity: :info

  # Models / concerns
  R.define :"models/concern-too-large",
    title: "Concern exceeds size threshold",
    category: :models,
    default_severity: :warning,
    doc_url: "https://dev.37signals.com/good-concerns/"

  R.define :"models/concern-too-small",
    title: "Concern is trivially small (premature abstraction)",
    category: :models,
    default_severity: :info

  R.define :"models/concern-bad-name",
    title: "Concern is not named as a trait (-able / -er / -ee / domain noun)",
    category: :models,
    default_severity: :info

  R.define :"models/anemic-model",
    title: "Model has only associations/validations and no domain methods",
    category: :models,
    default_severity: :info

  R.define :"models/fat-model",
    title: "Model exceeds size threshold",
    category: :models,
    default_severity: :warning

  R.define :"models/callback-overuse",
    title: "Model declares an excessive number of callbacks",
    category: :models,
    default_severity: :info,
    doc_url: "https://dev.37signals.com/globals-callbacks-and-other-sacrileges/"

  R.define :"models/uniqueness-without-index",
    title: "Uniqueness validation without a matching DB unique index",
    category: :models,
    default_severity: :warning

  R.define :"models/missing-presence-validation",
    title: "Non-nullable column without a presence validation in the model",
    category: :models,
    default_severity: :info

  R.define :"models/use-bang-methods",
    title: "Prefer create!/update!/save! over check-and-render flows",
    category: :models,
    default_severity: :info

  R.define :"performance/pluck-over-map",
    title: "Use .pluck(:attr) instead of .map(&:attr) on AR relations",
    category: :performance,
    default_severity: :info

  # Controllers
  R.define :"controllers/non-restful-action",
    title: "Controller defines a non-RESTful public action",
    category: :controllers,
    default_severity: :warning,
    doc_url: "https://jeromedalbert.com/how-dhh-organizes-his-rails-controllers/"

  R.define :"controllers/fat-controller",
    title: "Controller exceeds size threshold",
    category: :controllers,
    default_severity: :warning

  R.define :"controllers/heavy-application-controller",
    title: "ApplicationController has too many responsibilities (use concerns)",
    category: :controllers,
    default_severity: :info

  R.define :"controllers/before-action-overuse",
    title: "Excessive before_action filters in one controller",
    category: :controllers,
    default_severity: :info

  R.define :"controllers/respond-to-empty-block",
    title: "Empty `respond_to do |format| format.html end` block",
    category: :controllers,
    default_severity: :info

  # Routes
  R.define :"routes/non-restful",
    title: "Non-RESTful route declaration (member do / collection do / custom verbs)",
    category: :routes,
    default_severity: :warning

  R.define :"routes/verbs-not-nouns",
    title: "Custom verb route — extract to a noun resource (verbs become nouns)",
    category: :routes,
    default_severity: :info

  # Migrations / DB
  R.define :"db/missing-fk-index",
    title: "Foreign-key column without an index",
    category: :database,
    default_severity: :warning

  R.define :"db/missing-not-null",
    title: "Column without explicit null setting",
    category: :database,
    default_severity: :info

  R.define :"db/boolean-state-column",
    title: "Boolean state column — consider modeling as a relationship record",
    category: :database,
    default_severity: :info,
    doc_url: "https://dev.37signals.com/relationships-as-records/"

  R.define :"db/foreign-key-without-constraint",
    title: "Column ending in _id with no foreign-key constraint",
    category: :database,
    default_severity: :info

  R.define :"db/inconsistent-pk-types",
    title: "Mixed primary key types across migrations (UUID and bigint)",
    category: :database,
    default_severity: :info

  R.define :"db/timestamps-without-precision",
    title: "datetime column without explicit precision (Rails 7+ defaults to 6)",
    category: :database,
    default_severity: :info

  # Views / frontend
  R.define :"views/spa-with-importmap",
    title: "SPA frontend (React/Vue/etc.) coexists with importmap-rails",
    category: :views,
    default_severity: :info

  R.define :"views/dual-bundlers",
    title: "Multiple JS bundlers configured simultaneously",
    category: :views,
    default_severity: :warning

  R.define :"views/missing-resource-partial",
    title: "Resource view lacks a `_resource.html.erb` partial",
    category: :views,
    default_severity: :info

  R.define :"views/dom-id-string-literal",
    title: "Element id is a string literal — prefer dom_id helper",
    category: :views,
    default_severity: :info

  R.define :"views/api-and-html-controllers",
    title: "Jbuilder API endpoints mixed with HTML controllers in same namespace",
    category: :views,
    default_severity: :info

  R.define :"stimulus/file-naming",
    title: "Stimulus controller filename does not end in _controller.js",
    category: :views,
    default_severity: :info

  R.define :"stimulus/oversized",
    title: "Stimulus controller file exceeds size threshold",
    category: :views,
    default_severity: :info

  # Tests
  R.define :"tests/spec-and-test-coexist",
    title: "Both test/ and spec/ directories present",
    category: :tests,
    default_severity: :warning

  R.define :"tests/missing-test-coverage",
    title: "Module has no corresponding test file",
    category: :tests,
    default_severity: :info

  R.define :"tests/url-over-path",
    title: "Tests use *_url helpers instead of *_path",
    category: :tests,
    default_severity: :info

  R.define :"tests/factories-and-fixtures",
    title: "Both factory_bot factories and fixtures exist",
    category: :tests,
    default_severity: :warning

  # Stack consistency
  R.define :"stack/sprockets-and-propshaft",
    title: "Both sprockets and propshaft present",
    category: :stack,
    default_severity: :error

  R.define :"stack/missing-mission-control",
    title: "Solid Queue installed but mission_control-jobs missing",
    category: :stack,
    default_severity: :info

  R.define :"stack/vestigial-importmap",
    title: "importmap-rails binstub present but no config/importmap.rb",
    category: :stack,
    default_severity: :info

  R.define :"stack/redis-with-solid-cache",
    title: "Redis still in Gemfile alongside solid_cache",
    category: :stack,
    default_severity: :info

  R.define :"stack/devise-and-has-secure-password",
    title: "Devise installed alongside has_secure_password (duplicate auth)",
    category: :stack,
    default_severity: :warning

  R.define :"stack/sti-without-type-index",
    title: "STI model without index on the `type` column",
    category: :stack,
    default_severity: :info

  R.define :"arch/concerns-deep-dir",
    title: "Model concerns nested under app/models/concerns/<model>/ instead of app/models/<model>/",
    category: :architecture,
    default_severity: :info,
    doc_url: "https://dev.37signals.com/good-concerns/"

  # Security / dependencies (from wrappers)
  R.define :"security/brakeman",
    title: "Brakeman finding",
    category: :security,
    default_severity: :error

  R.define :"security/bundler-audit",
    title: "Vulnerable dependency",
    category: :security,
    default_severity: :error

  # Active record schema (from wrapper)
  R.define :"db/active-record-doctor",
    title: "active_record_doctor finding",
    category: :database,
    default_severity: :warning

  # Style / smells (from wrappers)
  R.define :"style/rubocop",
    title: "RuboCop offense",
    category: :smells,
    default_severity: :info

  R.define :"smells/reek",
    title: "Reek code smell",
    category: :smells,
    default_severity: :info

  # Dead code (from wrappers)
  R.define :"dead/debride",
    title: "Possibly unused method (debride)",
    category: :dead_code,
    default_severity: :info

  R.define :"dead/traceroute",
    title: "Unused or undefined route action (traceroute)",
    category: :dead_code,
    default_severity: :info
end
