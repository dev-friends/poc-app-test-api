# AGENTS.md

Rails 8 API-only app that triggers browser (Capybara/Cuprite) test runs against an
*external* application and exposes results over HTTP. See `README.md` for the API
reference and the full Docker walkthrough.

## Two RSpec suites — do not merge their configs

| Path | Tests | How it runs |
|------|-------|-------------|
| `spec/` | this Rails app (requests, jobs) | `bundle exec rspec` |
| `test_suites/external_app/` | the **external** app under test | spawned as a subprocess by `RunExternalTestSuiteJob` |

- `test_suites/external_app/` is a **standalone** suite: its own `.rspec`,
  `spec_helper.rb`, and `Capybara.app_host`. It is *not* picked up by the root
  `bundle exec rspec` (default pattern is `spec/**/*_spec.rb`) — that is intentional.
- The job shells out via `Open3.capture3("bundle", "exec", "rspec", ...)` on purpose:
  `RSpec::Core::Runner` is not safe to re-invoke inside a long-lived worker process.
  Don't "optimize" this into an in-process call.
- Root `.rspec` only has `--require spec_helper`, so every file in `spec/` must
  `require "rails_helper"` explicitly.
- `rspec`, `capybara`, and `cuprite` are **production** dependencies (not dev/test) —
  the worker needs them at runtime. Keep them out of the `:development, :test` group.

## Commands

```bash
bundle exec rspec                          # this app's suite (fast, no browser/network)
bundle exec rspec spec/jobs/run_external_test_suite_job_spec.rb:14   # single example
bin/rubocop                                # rubocop-rails-omakase
bin/ci                                     # setup + rubocop + bundler-audit + brakeman
foreman start -f Procfile.dev              # web + jobs worker locally
```

`bin/dev` only `exec`s `bin/rails server` — it does **not** start the Solid Queue
worker, so triggered runs stay `pending` forever. Use `Procfile.dev` (foreman is
not a Gemfile dependency; `gem install foreman`) or run `bin/jobs` in a second
terminal.

`bin/ci` and `.github/workflows/ci.yml` run **lint + security only — no tests**.
Always run `bundle exec rspec` yourself before claiming a change is verified.

Ruby 4.0.6 is pinned by `mise.toml` / `.ruby-version`; use `mise install` + `bundle install`.

## Domain invariant: one active run at a time

`db/migrate/*_create_test_runs.rb` creates a SQLite partial unique index on a
*constant expression* (`ON test_runs ((1)) WHERE status IN ('pending','running')`).
A plain unique index on `status` would not prevent one `pending` + one `running`
coexisting. Creating a second active run raises `ActiveRecord::RecordNotUnique`,
which `TestRunsController#create` rescues into a `409`. Tests that create multiple
runs must finish/destroy the previous one first.

## Databases

Two SQLite databases per env (`config/database.yml`): `primary` and `queue`
(Solid Queue, `db/queue_migrate`). Production adds `cache` and `cable`.
Use `bin/rails db:prepare`, not `db:migrate`, so all of them are handled.

## Docker specifics

- Containers run `RAILS_ENV=production` and require `RAILS_MASTER_KEY` in `.env`
  (copy from `config/master.key`). No key → every request 500s on decryption.
- Repo is bind-mounted (`.:/rails`), so code edits are live. Rebuild
  (`docker compose up --build`) **only** after changing `Gemfile` or `Dockerfile`
  (gems live in `/usr/local/bundle`, outside the mount).
- `bin/docker-entrypoint` runs `db:prepare` only when the command ends with
  `./bin/rails server`, i.e. the `web` container. The `jobs` container depends on
  `web` having prepared the shared `db_data` volume first.
- The image installs Chromium and sets `CHROME_BIN`; `support/capybara_setup.rb`
  adds `--no-sandbox`/`--disable-dev-shm-usage` only when `CHROME_BIN` is set.
  Locally Cuprite auto-discovers Chrome instead.
- `config/deploy.yml` (Kamal) is still the stock generated template with a
  placeholder IP — nothing deploys through it today.

## Conventions & gotchas

- Never commit `.env` or `config/master.key`. `opencode/data/` (holds `auth.json`)
  is gitignored; `opencode/config/` is **tracked** — don't put secrets there.
- JSON is rendered by hand-rolled classes in `app/serializers/` (plain POROs with
  `as_json`), not a serializer gem. Follow that pattern.
- Default target when `SAMPLE_EXTERNAL_APP_URL` is unset is
  `https://the-internet.herokuapp.com`, a sleeping free Heroku dyno — the first run
  after idle can fail transiently. One example in `test_suites/external_app/specs/`
  fails *deliberately* to demonstrate `error_message` capture.
- A spec that must always hit a different, fixed host (independent of whatever
  `SAMPLE_EXTERNAL_APP_URL`/`target_url` the run uses) can tag its `describe` block
  with `app_host: "https://..."`; `support/app_host.rb` overrides
  `Capybara.app_host` for just that spec's examples and restores it afterward.
