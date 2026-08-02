# Matilda agent notes

## Project

Ruby on Rails project management app. Uses Hotwire, Stimulus, Bootstrap, Sprockets, import maps.

## Environment

- Ruby version: see `.ruby-version`
- Install: `bundle install`
- Test: `bin/rails test`
- System test: `bin/rails test:system`

## API

- JSON API under `/api/v1` (`app/controllers/api/v1`), authenticated with a per-user API key (`X-API-Key` header). The key authenticates a real user, so `Users::Policy` checks and the `only_data_projects_as_member` scoping apply to API requests too.
- Users generate/regenerate their key from their profile page ("Rigenera API Key"); the key is shown only once.
- OpenAPI spec lives in `config/openapi/v1.yaml`, served at `/api/v1/openapi` with Swagger UI at `/api/v1/docs`. A test (`test/controllers/api/v1/docs_test.rb`) fails if a route is missing from the spec — update the YAML when adding endpoints.

## Crew

- `crew/` is a standalone Node.js CLI package (`matilda-crew`) that runs Claude-powered pseudo-employees against the API v1: each employee is a real Matilda user polled for assigned tasks. See `crew/README.md`.
- `rake crew:pack` builds the npm tarball + `manifest.json` into `public/crew/` (gitignored); the web page at `/crew` (tools section) shows install instructions and `crew update` uses the manifest for self-updates.
- Comment activity does NOT touch a task's `updated_at`; the crew loop relies on the task `unresolved` flag (true when the last comment is not the assignee's).
- `unresolved`, `tasks_comments_count` and `last_comment_user_id` on `tasks` are denormalized by `Tasks::Comment` (see `sync_task_comment_state`), so task cards render comment info without a query per card. `unresolved` is API/crew-only: the card shows the comment count and the last author instead.

## Conventions

- Ruby strings use double quotes.
- Prefer Bootstrap utility classes and existing shared partials.
- Keep accessibility attributes on icon-only controls.
- JavaScript follows Standard Style: no semicolons, single quotes, 2-space indent.
