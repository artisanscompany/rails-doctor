#!/usr/bin/env node
// rails-doctor Node wrapper.
//
// Distribution model: this package ships the Ruby source files (in lib/, exe/,
// skills/). At runtime we shell out to the user's system Ruby. Every Rails
// developer already has Ruby installed, so this avoids the friction of a
// separate `gem install` step and matches react-doctor's `npx`-first UX.
//
// Zero npm runtime deps. The Ruby side is also zero-gem-deps (stdlib only).

"use strict";

const { spawnSync } = require("node:child_process");
const path = require("node:path");
const fs = require("node:fs");

const PACKAGE_ROOT = path.resolve(__dirname, "..");
const RUBY_EXE = path.join(PACKAGE_ROOT, "exe", "rails-doctor");
const RUBY_LIB = path.join(PACKAGE_ROOT, "lib");

function findRuby() {
  const env = process.env.RAILS_DOCTOR_RUBY;
  if (env) return env;

  const candidates = ["ruby"];
  if (process.platform === "darwin") {
    candidates.push("/opt/homebrew/bin/ruby", "/usr/local/bin/ruby");
  }

  for (const candidate of candidates) {
    const probe = spawnSync(candidate, ["--version"], { stdio: "pipe" });
    if (probe.status === 0) return candidate;
  }
  return null;
}

function ensureRubyVersion(ruby) {
  const result = spawnSync(ruby, ["-e", "puts RUBY_VERSION"], { stdio: "pipe" });
  if (result.status !== 0) return false;
  const version = result.stdout.toString().trim();
  const [major, minor] = version.split(".").map(Number);
  return major > 3 || (major === 3 && minor >= 1);
}

function bail(message, code = 2) {
  process.stderr.write(`rails-doctor: ${message}\n`);
  process.exit(code);
}

function main() {
  if (!fs.existsSync(RUBY_EXE)) {
    bail(`bundled Ruby entry point missing: ${RUBY_EXE}`, 3);
  }

  const ruby = findRuby();
  if (!ruby) {
    bail(
      "Ruby is required but was not found on PATH.\n" +
        "Install Ruby (>= 3.1) and re-run, or set RAILS_DOCTOR_RUBY to a Ruby executable."
    );
  }

  if (!ensureRubyVersion(ruby)) {
    bail("rails-doctor requires Ruby >= 3.1. Found older version.", 4);
  }

  const args = ["-I", RUBY_LIB, RUBY_EXE, ...process.argv.slice(2)];
  const result = spawnSync(ruby, args, { stdio: "inherit" });

  if (result.error) {
    bail(`failed to spawn Ruby: ${result.error.message}`, 5);
  }
  process.exit(result.status === null ? 1 : result.status);
}

main();
