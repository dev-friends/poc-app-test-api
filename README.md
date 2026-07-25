# App Test API

A Rails API that runs UI (browser) tests against an external application and
exposes the run status and results over HTTP, so another application can
trigger test runs and consume their results.

## How it works

1. A client `POST`s to `/test_runs` to trigger a run.
2. The request creates a `TestRun` record (`status: pending`) and enqueues
   `RunExternalTestSuiteJob` on Solid Queue, then returns immediately.
3. A background worker (`bin/jobs`) picks up the job, shells out to
   `bundle exec rspec` against the standalone suite in
   `test_suites/external_app/`, and marks the run `running`.
4. That suite drives a headless Chrome browser (via Capybara + Cuprite)
   against the external application's UI, at the URL configured by
   `SAMPLE_EXTERNAL_APP_URL` (or the `target_url` passed when triggering).
5. RSpec's `--format json` output is parsed by the job and persisted as a
   `TestCaseResult` per example, and the `TestRun` is marked `completed` or
   `failed`.
6. The client polls `/test_runs/status` and reads `/test_runs/:id/results`.

### Architecture

- **Rails 8 (API-only)** — no views/assets, just JSON endpoints.
- **Solid Queue** — background job backend that persists jobs in the
  database itself, so there's no Redis to run/maintain.
- **SQLite** — one file for the app's own tables, one for Solid Queue's
  tables (see `config/database.yml`).
- **Two separate RSpec suites, deliberately not sharing config:**
  - `spec/` (with `rspec-rails`) tests **this Rails app itself**
    (controllers, jobs, models).
  - `test_suites/external_app/` is a **standalone** RSpec + Capybara +
    Cuprite suite that tests the **external application under test**. It
    has its own `.rspec`, `spec_helper.rb` and `Capybara.app_host`, and is
    invoked by the job via a separate `bundle exec rspec` process — never
    in-process, since `RSpec::Core::Runner` isn't safe to invoke repeatedly
    inside a long-lived worker process.

```
app_test_api/
├── app/
│   ├── controllers/test_runs_controller.rb
│   ├── models/{test_run.rb, test_case_result.rb}
│   ├── serializers/{test_run_serializer.rb, test_case_result_serializer.rb}
│   └── jobs/run_external_test_suite_job.rb
├── test_suites/external_app/   # tests the EXTERNAL app
│   ├── .rspec
│   ├── spec_helper.rb
│   ├── support/capybara_setup.rb
│   └── specs/*.rb
├── spec/                       # tests THIS Rails app
├── db/migrate/
├── Dockerfile
└── docker-compose.yml
```

## Setup (local, no Docker)

Requirements: [mise](https://mise.jdx.dev/) (pins Ruby 4.0.6 via `mise.toml`
in this repo) and a local Chrome/Chromium install (Cuprite finds it
automatically on macOS).

```bash
mise install
bundle install
bin/rails db:prepare
```

Run both processes (web server + Solid Queue worker):

```bash
foreman start -f Procfile.dev
# or, in two terminals:
# bin/rails server
# bin/jobs
```

## Setup with Docker

```bash
cp .env.example .env
# edit .env: RAILS_MASTER_KEY=<contents of config/master.key>

docker compose up --build
```

This starts two containers from the same image: `web` (Puma, port 3000) and
`jobs` (the Solid Queue worker), sharing a SQLite volume. The image installs
Chromium so Cuprite has a browser to drive headlessly.

## Triggering a run and viewing results

Out of the box — with no configuration — the bundled example specs run
against a public demo site (`https://the-internet.herokuapp.com`), so the
whole pipeline is testable immediately:

```bash
curl http://localhost:3000/test_runs/status
# {"running":false,"current_run":null,"last_run":null,"ever_run":false}

curl -X POST http://localhost:3000/test_runs
# 201 { "id": 1, "status": "pending", ... }

curl -X POST http://localhost:3000/test_runs
# 409 while the first run is still active: { "error": "...", "current_run": {...} }

curl http://localhost:3000/test_runs/status
# poll until "running": false

curl http://localhost:3000/test_runs/1
curl http://localhost:3000/test_runs/1/results
# 2 passed, 1 failed (deliberately, to demonstrate error_message capture)

curl http://localhost:3000/test_runs
```

> **Note:** `the-internet.herokuapp.com` runs on a free Heroku dyno that
> sleeps after inactivity. The very first run after a while may report an
> infra-level failure (its dyno waking up returns a transient `503`) —
> if that happens, just trigger the run again.

## Pointing at the real application under test

1. Set `SAMPLE_EXTERNAL_APP_URL` (env var, used as the default) or pass
   `target_url` in the `POST /test_runs` body (used for that run only) to
   the real app's base URL.
2. Add specs under `test_suites/external_app/specs/` that exercise its
   screens with Capybara (`visit`, `fill_in`, `click_button`,
   `expect(page).to have_content(...)`, etc.).

## API reference

| Method | Route                     | Description                                                              |
|--------|---------------------------|----------------------------------------------------------------------------|
| GET    | `/test_runs/status`       | `{ running, current_run, last_run, ever_run }` — current state at a glance |
| POST   | `/test_runs`               | Triggers a run (`target_url` optional). `201` + run, or `409` if one is active |
| GET    | `/test_runs`               | Lists past runs (most recent first)                                       |
| GET    | `/test_runs/:id`           | One run, with its `test_case_results` nested                             |
| GET    | `/test_runs/:id/results`   | Just the individual test case results for that run                       |

Example `GET /test_runs/:id`:

```json
{
  "id": 1,
  "status": "failed",
  "target_url": null,
  "started_at": "2026-07-25T19:02:42.221Z",
  "finished_at": "2026-07-25T19:02:59.436Z",
  "duration_seconds": 17.22,
  "total_count": 3,
  "passed_count": 2,
  "failed_count": 1,
  "pending_count": 0,
  "error_message": null,
  "test_case_results": [
    { "id": 1, "full_description": "Homepage loads and shows the list of available examples", "status": "passed", "run_time": 2.73, "error_message": null },
    { "id": 2, "full_description": "Login authenticates with valid credentials", "status": "passed", "run_time": 1.99, "error_message": null },
    { "id": 3, "full_description": "Login rejects invalid credentials (deliberately failing example)", "status": "failed", "run_time": 11.9, "error_message": "expected to find text \"this-text-does-not-exist-on-purpose\" in \"...\"" }
  ]
}
```

## Running this app's own test suite

```bash
bundle exec rspec
```

This covers `TestRunsController` and `RunExternalTestSuiteJob` (with
`Open3.capture3` stubbed) — it does not launch a browser or hit the network.
