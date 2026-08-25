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

## Tasks

- Comment activity does NOT touch a task's `updated_at`; the `unresolved` flag tracks it instead (true when the last comment is not the assignee's).
- `unresolved`, `tasks_comments_count` and `last_comment_user_id` on `tasks` are denormalized by `Tasks::Comment` (see `sync_task_comment_state`), so task cards render comment info without a query per card. `unresolved` is API-only: the card shows the comment count and the last author instead.

## CRM (contacts / campaigns / communications)

- Three models: `Contact` (anagrafica), `Campaign`, `Communication` (the contact↔campaign relation, unique per pair) + `Communications::Log` (rich text notes on a communication, `has_rich_text :content`). Sections mirror the Projects structure (explicit routes, `actions` modal dispatcher).
- The whole section is gated by the single `crm` policy (like `settings`/`tools`). One "Crm" nav dropdown (Dashboard `/crm` + Contatti + Campagne); `CrmController#index` is the summary dashboard (stats, active campaigns, to-send / waiting lists).
- Contacts and campaigns are archivable like projects (`archived` boolean, archive/unarchive policies and actions, index filter defaults to non-archived, dark card when archived). Contact cards only show `Communication.ongoing` badges (to_send/sent).
- `Communication` states are forward-only (`Communication::TRANSITIONS`): `to_send → sent → lost|won`. Moving to `sent` confirms and stores `sent_date`; closing stores `closed_date`. No going back — delete and recreate instead. Each step runs once from its own state (`mark_sent`/`mark_closed` refuse to rewrite a confirmed date and add the error to the record), and follow-ups are dated records (`Communications::FollowUp`, `follow_ups_count` is their counter cache) registered only while `sent`, listed in the communication detail overlay and undoable one by one.
- API: contacts and campaigns are readable (plus contact creation and communication enqueuing), and `/api/v1/communications/:id` exposes a communication with its state transitions (`send`, `close`, `follow_up`) and its notes (`logs` GET/POST, `logs/:log_id` DELETE) and its follow-ups (`follow_up` POST, `follow_ups/:follow_up_id` DELETE). Note content is rich text: `as_json(with_content: true)` opts into the HTML, same pattern as `Task`.
- Campaign show is a 4-column board (`campaigns/_kanban`, `c-comm-board*`, no drag) with a segmented distribution bar; each column reads in its own order (`Communication.board_order`: oldest queued/waiting first, latest outcomes on top) and cards show how long a sent one has been silent (`days_since_last_activity`: from the send or the latest follow-up, whichever is newer — warning after `SILENCE_WARNING_DAYS`, danger after `SILENCE_URGENT_DAYS`). A silent communication is flagged on its card, counted in the board stats and gets an alert in the overlay with the two ways out (sollecita / registra esito).
- Board cards carry no menu: the whole card opens the detail overlay, which holds every action (send, outcome, follow-up, delete) plus the state timeline and the Follow-up / Note tabs. In the Note tab the notes read as a `c-timeline` and the Trix composer is anchored at the bottom, outside the scroller (only the timeline scrolls) — Trix inside a scrolling container makes the scroll glitch.
- Editing follow-ups or notes answers with turbo streams replacing both the `action` frame (the overlay stays open on the tab the action came from, via `@active_tab`) and the `campaign-kanban` frame.
- `Project belongs_to :contact` (optional, `dependent: :nullify` on the contact side). Contact select in the project form, "Progetti" module with link/unlink on the contact page (policy `contacts_edit`). Project cards show the contact via `Project#cached_contact_name` (Rails-cache, invalidated on contact rename/destroy and on `contact_id` change).

## Conventions

- Ruby strings use double quotes.
- Prefer Bootstrap utility classes and existing shared partials.
- Keep accessibility attributes on icon-only controls.
- JavaScript follows Standard Style: no semicolons, single quotes, 2-space indent.
