# Changelog

## [0.3.0] - 2026-11-18

### Added
- Web interface, mounted separately from the API: `mount Trailticket::Web => "/admin/tickets"`.
  Kanban with drag and drop between status columns, list with search/filters/pagination and
  ticket page with origin URL, navigation trail and the rest of the context.
  Own layout, CSS and JS served by the engine (no dependency on the host's assets or frameworks);
  English and Brazilian Portuguese translations; overridable views
- Ticket history: status moves, close/reopen, priority and assignee changes are recorded in a
  new `trailticket_events` table with who made them, and shown on the ticket page in one
  timeline with replies and internal notes
- Replies and internal notes from the ticket page, written by `current_actor`
- `Trailticket.with_actor(user) { ... }` to record who made changes from the app's own code;
  the web interface and the JSON API set it for each request
- Config: `authorize` (denies by default), `current_actor`, `author_label`, `subject_label`,
  `context_partial`, `statuses`
- `spec/dummy` runs as a local app with sample data: `bin/dummy`

### Upgrading
- New migration: `bin/rails trailticket:install:migrations && bin/rails db:migrate`.
  Until it runs, tickets keep working but no history is recorded

### Changed
- `status` is no longer an Active Record enum: it is validated against `config.statuses`.
  `status_open?`, `status_closed?` etc. still work; `Ticket.status_open` scopes and
  `Ticket.statuses` (the enum hash) are gone. The last status is final (`closed` by default)
- The JSON API (`/me`, `GET /tickets?status=`) uses `config.statuses`

## [0.2.0] - 2026-11-18

### Added
- `Trailticket.open_ticket` / `OpenTicket`: `metadata:` to store the app's own data in the
  ticket context (trusted, not sanitized; reserved keys `page`, `trail`, `fields`, `errors`
  raise `ArgumentError`) and `page_url:` to set the ticket URL (cleaned) instead of `context.page.url`
- `Trailticket::ContextSanitizer.clean_url(url)` class method

### Fixed
- JS: `capture(options)` accepts options; when it runs before `start()` the collector now starts
  with them instead of the defaults (e.g. honouring `captureValues: false`)

### Changed
- Removed comments from the migrations copied into the app

## [0.1.0] - 2026-11-05

### Added
- Tickets with title, body, status, priority, assignee and optional polymorphic subject
- Replies, with internal notes visible only to managers
- Close and reopen, tracking `closed_at` and `closed_by`
- Per-app permissions: `can_open` and `can_manage`
- JSON API: `/me`, tickets, messages, close/reopen, screenshot
- Ruby API: `Trailticket.open_ticket`
- Context capture: page, navigation trail, filled-in fields, JS errors, DOM screenshot
- Sensitive data masked in the browser and again on the server (`filter_parameters` + `sensitive_fields`)
- Dependency-free JavaScript collector and API client
- Hooks: `on_ticket_created`, `on_message_created`, `on_status_changed`
- `trailticket:install` generator
