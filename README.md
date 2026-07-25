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

Requirements: Docker and Docker Compose (`docker compose version`). Nothing
else — Ruby, Chromium and every gem are built into the image.

### 1. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` and set `RAILS_MASTER_KEY` to the contents of `config/master.key`
(Rails needs it to boot in `RAILS_ENV=production`, which is what the
container runs):

```bash
echo "RAILS_MASTER_KEY=$(cat config/master.key)" > .env
echo "SAMPLE_EXTERNAL_APP_URL=https://the-internet.herokuapp.com" >> .env
```

`.env` is gitignored — never commit it or `config/master.key`.

### 2. Build and start

```bash
docker compose up --build
```

(add `-d` to run in the background). This builds one image and starts two
containers from it:

- `web` — Puma, serving the API on `http://localhost:3000` (proxied through
  Thruster, which listens on container port 80 and forwards to Rails on
  3000 internally).
- `jobs` — the Solid Queue worker (`bin/jobs`), which is what actually runs
  `bundle exec rspec` against the target app when a test run is triggered.

Both share a `db_data` volume (`/rails/storage`) so they see the same SQLite
databases. The image installs Chromium (`chromium` + `fonts-liberation`) so
Cuprite has a real headless browser to drive inside the container.

### 3. Use the API

Same requests as the local setup, just against the containerized server:

```bash
curl http://localhost:3000/test_runs/status
curl -X POST http://localhost:3000/test_runs
curl http://localhost:3000/test_runs/1/results
```

### 4. Logs, rebuilding, stopping

```bash
docker compose logs -f jobs   # watch the worker pick up and run a test suite
docker compose logs -f web    # watch request/response activity

docker compose up --build     # rebuild after changing the Gemfile or code

docker compose down           # stop and remove containers (keeps the db_data volume)
docker compose down -v        # also wipe the SQLite volume (fresh start)
```

### Troubleshooting

- **Boots but every request 500s with a decryption error**: `RAILS_MASTER_KEY`
  in `.env` doesn't match `config/master.key` (or wasn't set at all).
- **`SolidQueue::Job::EnqueueError` / "Could not find table"**: the queue
  database wasn't migrated — rebuild (`docker compose up --build`), which
  runs `bin/docker-entrypoint` → `bin/rails db:prepare` on boot.
- **A run finishes in a second or two with every example failing**: check
  `docker compose logs jobs` for the actual Capybara/Cuprite error first.
  If it's a Capybara timeout on the bundled example specs, the public demo
  site is very likely just asleep (see the note further below) — retrigger
  the run.

### Running opencode inside the container

The image also has [opencode](https://opencode.ai) installed (same
`web`/`jobs` image, no extra build step needed) so you can use it against
this codebase from inside the container:

Authenticate one of two ways:

- **Env var (recommended for this setup)**: set `OPENCODE_API_KEY` in `.env`.
  The entrypoint (`bin/docker-entrypoint`) writes it into
  `~/.local/share/opencode/auth.json` on every boot, so both `web` and `jobs`
  come up already authenticated — nothing to do inside the container.
- **Interactive login**: leave `OPENCODE_API_KEY` unset and run
  `docker compose exec web opencode auth login` the first time.

```bash
docker compose exec web opencode
```

Either way, credentials and config persist across container
restarts/rebuilds: the `opencode/data` and `opencode/config` directories in
this repo are bind-mounted to `~/.local/share/opencode` and
`~/.config/opencode` inside the container (see `docker-compose.yml`). Both
directories are gitignored — the folders themselves are tracked (via
`.keep`) but their contents (your actual credentials) never get committed.

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
