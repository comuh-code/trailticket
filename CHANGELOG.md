# Changelog

## [0.6.6] - 2026-11-18

### Changed
- Removed the "Tickets" title next to the Board/List tabs: inside the host app's layout, which
  usually has its own title, it showed the name twice

## [0.6.5] - 2026-11-18

### Changed
- The design system page and its footer link are off by default: they are a reference for
  developing the panel, not for the people handling tickets. Turn them on with
  `config.web_design_system = true`

## [0.6.4] - 2026-11-18

### Fixed
- Board columns all have the same height (the closed column used to be taller than the others)
- The "No priority (suggested: …)" badge wraps inside the card instead of overflowing it
- Filter selects are as wide as their longest option, so "Anyone" and the others are not cut off
- In the list, avatars and names stay on one line
- The filters' "Clear" button looks like a button (bordered, same size as "Filter")

### Changed
- The list's "List" heading is only for screen readers, like the board's

## [0.6.3] - 2026-11-18

### Changed
- Removed explanatory comments from the code and specs. The configuration docs
  (`lib/trailticket/configuration.rb` and the install generator's initializer) are kept. No
  behavior change

## [0.6.2] - 2026-11-18

### Fixed
- Release dates in this changelog: 0.4.0 to 0.6.1 were all released on 2026-11-18

## [0.6.1] - 2026-11-18

### Added
- The board has the list's filters: search, priority and assignee (anyone, assigned to me,
  unassigned or a person). Counters follow the filters, the "see all" link keeps them, and they
  live in the URL (e.g. `/admin/tickets?assignee=me`). Status and archived stay list-only: each
  column is a status and the board never shows archived tickets

## [0.6.0] - 2026-11-18

### Added
- Assignee column in the ticket list
- Assignee filter in the list: anyone, assigned to me, unassigned or a specific person
- The ticket page shows who set the current assignee and when ("set by Sergio · …")

## [0.5.3] - 2026-11-18

### Changed
- The web interface's views are HAML (`.html.haml`) instead of ERB; the rendered HTML is the
  same. trailticket now depends on the `haml` gem, which it loads itself, so host apps don't
  need to use HAML. Views overridden by the app can be ERB or HAML

## [0.5.2] - 2026-11-18

### Added
- Light and dark themes for the web interface: `config.web_theme` (`"auto"`, the default, follows
  the browser; `"light"`; `"dark"`)
- `config.web_stylesheet`: a stylesheet of the host app loaded after the panel's CSS to override
  its `--tt-*` tokens (accent color, font...)
- Design system page in the panel (`/design-system`, linked in the footer) with tokens and every
  component in both themes

### Changed
- New visual design for the board, list and ticket page: priority badges with icons, status dots,
  avatars, a timeline for the navigation trail, dashed internal notes and 44 px touch targets
- All CSS is scoped to `.tt` and all tokens are `--tt-*` custom properties, so the panel does not
  leak styles into (or inherit them from) the host app. Custom views that relied on the old token
  names (`--tt-low`, `--tt-high`...) need the new ones

## [0.5.1] - 2026-11-18

### Changed
- Code follows the project's RuboCop config (compact `class Trailticket::X` style, single
  quotes, `frozen_string_literal`); CI lint passes. No behavior change
- `.rubocop.yml` targets Rails 7.1, the oldest supported version

### Fixed
- Engine classes inherit explicitly from `Trailticket::ApplicationRecord` and
  `Trailticket::ApplicationController`

## [0.5.0] - 2026-11-18

### Added
- Triage (`config.triage`, off by default): tickets start in `initial_status` without a
  priority, the priority the user picked is kept as `suggested_priority`, and a ticket can only
  move from the initial status to a non-final one after it has a priority (board, buttons, JSON
  API and Ruby). Going straight to a final status is allowed
- Priority and assignee can be set on the ticket page (recorded in the history)
- Board work columns ordered by priority (most urgent first, no priority last), then oldest
  first; final columns by most recently closed
- "No priority" filter in the list; `suggested_priority` in the JSON API

### Changed
- `priority` may be `nil` (only with triage on); without triage new tickets still default to
  `normal`

### Upgrading
- New migration: `bin/rails trailticket:install:migrations && bin/rails db:migrate`

## [0.4.0] - 2026-11-18

### Added
- `initial_status` and `final_statuses` config. Several final statuses are supported
  (e.g. resolved and cancelled): entering any of them fills `closed_at`/`closed_by`, moving
  between them keeps both. The config is validated when the app boots
- Archiving: tickets in a final status can be archived from the card or the ticket page, which
  hides them from the board and the default list. "Archived" filter in the list, unarchive
  button, entries in the history; reopening unarchives. `Ticket#archive!`/`#unarchive!`,
  `archived`/`unarchived` scopes and `archived_at` in the JSON API
- `board_closed_days` (default 7): final columns of the board only show recently closed tickets
- `on_status_changed` receives who made the change as a 4th argument; hooks with three
  arguments keep working

### Changed
- No more silent fallback when a migration is missing: without `trailticket_events`, updating
  a ticket raises instead of skipping the history (0.3.0 skipped it without warning)

### Upgrading
- New migration: `bin/rails trailticket:install:migrations && bin/rails db:migrate`.
  Updating the gem does not copy migrations: without `install:migrations` the app does not see
  them as pending, and the board, the list and ticket updates fail

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
