# Changelog

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
