# Trailticket

Headless support tickets for Rails that carry the user's context.

When a user reports a problem, the ticket arrives with **where they were and what they did**:
the page URL, a screenshot, the path they took through the app, the fields they filled in and
any JavaScript errors — with passwords, tokens, card numbers and other sensitive data masked
in the browser *and again* on the server.

It gives you:

- a mountable **JSON API** (tickets, replies, internal notes, status, assignee, close/reopen),
- a **Ruby API** (`Trailticket.open_ticket`) and plain Active Record models,
- a dependency-free **JavaScript collector** that records context and talks to the API,
- an optional **web interface** for your team (kanban, list, ticket page), mounted like
  Sidekiq Web — see [Web interface](#web-interface).

The screens your users see (the "report a problem" form) you build with whatever your app
already uses — Bootstrap, Tailwind, Hotwire, React.

Requires Rails 7.1+ and Ruby 3.1+. Screenshots need Active Storage.

## Installation

```ruby
# Gemfile — pin a tag so updates are deliberate
gem "trailticket", git: "https://github.com/comuh-code/trailticket.git", tag: "v0.3.0"
```

```bash
bundle install
bin/rails g trailticket:install          # initializer, route and migrations
bin/rails active_storage:install         # only if you don't have it yet
bin/rails db:migrate
```

The engine is mounted at `/trailticket` (change it with `--path=/support`).

## Configuration

`config/initializers/trailticket.rb`. Example where users with role `member` or `agent`
open tickets, and only `agent`s handle them:

```ruby
Trailticket.configure do |c|
  c.user_class = "Admin"
  c.current_user_method = :current_admin
  c.authenticate = -> { authenticate_admin! }

  c.can_open   = ->(admin) { admin.role.in?(%w[member agent]) }
  c.can_manage = ->(admin) { admin.role == "agent" }

  c.assignees = -> { Admin.where(role: "agent").order(:name) }
  c.user_json = ->(admin) { { id: admin.id, name: admin.name } }

  c.on_ticket_created = ->(ticket) { SupportMailer.new_ticket(ticket).deliver_later }
end
```

| Option | Default | |
| --- | --- | --- |
| `user_class` | `"User"` | Class of the people who open and handle tickets |
| `current_user_method` | `:current_user` | Controller method returning the signed-in user |
| `authenticate` | `nil` | Block run in the controller before every action |
| `can_open` | denies all | `->(user)` may open tickets and see their own |
| `can_manage` | denies all | `->(user)` sees all, replies, internal notes, status, assignee, close/reopen |
| `assignees` | `nil` | `-> { relation }` who can be assigned; without it, only yourself |
| `user_json` | id + name | `->(user)` how users appear in the API — keep it minimal |
| `parent_controller` | `"ApplicationController"` | Use `"ActionController::API"` in API-only apps |
| `access_denied` | 403 JSON | Block run when access is denied |
| `statuses` | `open in_progress waiting closed` | Ordered statuses (and board columns) |
| `initial_status` | first of `statuses` | Status of new tickets |
| `final_statuses` | last of `statuses` | One or more "done" statuses: entering one fills `closed_at`/`closed_by` |
| `triage` | `false` | Tickets start without priority (the user's pick is a suggestion) and must be prioritized before leaving `initial_status` |
| `on_ticket_created`, `on_message_created`, `on_status_changed` | `nil` | Hooks, run after commit |
| `sensitive_fields` | pass, secret, token, card, cvv, cvc, cpf, cnpj, ssn, iban, otp, pin | Extra names to mask, on top of `filter_parameters` |
| `capture_field_values` | `true` | `false` keeps only *which* fields were filled |
| `max_trail_entries` / `max_fields` / `max_errors` / `max_value_length` | 50 / 100 / 20 / 500 | Limits applied on the server |
| `max_screenshot_bytes` | 5 MB | |
| `screenshot_content_types` | png, jpeg, webp | Content is checked against the type |

### Permissions

| Action | `can_open` | `can_manage` |
| --- | --- | --- |
| Open a ticket | ✅ | only if also `can_open` |
| See tickets | own | all |
| Reply | own, while not closed | any |
| Internal notes | ❌ (never sees them) | ✅ |
| Status, priority, assignee | ❌ | ✅ |
| Close / reopen | ❌ | ✅ |

## Capturing context

Load `trailticket.js` (served from the gem). With importmap:

```ruby
# config/importmap.rb
pin "trailticket", to: "trailticket.js"
pin "modern-screenshot" # optional, for screenshots: bin/importmap pin modern-screenshot
```

With a bundler (esbuild, Vite...), copy the file from the gem's `app/assets/javascripts`
into your app for now.

```js
import * as Trailticket from "trailticket"
import { domToJpeg } from "modern-screenshot"

// Once, on every page — starts recording the trail and JS errors.
Trailticket.start({
  endpoint: "/trailticket",
  screenshot: Trailticket.domScreenshot(domToJpeg),
})

// When the user clicks "Report a problem" — BEFORE opening your form,
// so the screenshot and fields show the page, not the form.
const snapshot = await Trailticket.capture()
// If capture() may run before start() (e.g. start() lives in another bundle),
// pass the same options, otherwise the collector starts with the defaults:
//   await Trailticket.capture({ captureValues: false })

// ...after the user writes the description in your own form:
const ticket = await Trailticket.submit({ title, body, priority: "high" }, snapshot)
```

What is captured:

| | |
| --- | --- |
| `page` | URL, referrer, title, user agent, language, timezone, viewport, screen size |
| `trail` | Last 50 visits, clicks and form submits (kept in `sessionStorage`, so it survives full page loads in the tab) |
| `fields` | Filled-in inputs, selects and textareas, with name, label and value |
| `errors` | Last 20 uncaught errors and unhandled promise rejections |
| screenshot | Rendered from the DOM; masked and ignored elements are left out |

**Privacy.** Values are masked when the field is a password, its name/id/label/autocomplete
matches `sensitive` (client) or `sensitive_fields` + `filter_parameters` (server), or it sits
inside `[data-trailticket-mask]`. Sensitive query params are masked in every URL.
Mark your report form with `data-trailticket-ignore` so it isn't recorded at all.

```html
<div data-trailticket-mask>Card ending in 4242</div>
<div id="report-modal" data-trailticket-ignore>...</div>
```

You are responsible for telling your users what is collected.

**Screenshots** are rendered from the DOM, so no browser permission prompt appears, but
cross-origin iframes, `<canvas>` and some external fonts may not render exactly.

### JS client

`Trailticket.api` wraps the endpoints for building your own screens:

```js
await Trailticket.api.me()                     // permissions, statuses, assignees
await Trailticket.api.list({ status: "all", page: 1 })
await Trailticket.api.get(id)
await Trailticket.api.reply(id, "On it", { internal: true })
await Trailticket.api.update(id, { status: "in_progress", assignee_id: 3 })
await Trailticket.api.close(id)
Trailticket.api.screenshotUrl(id)              // use in <img src>
```

Requests send the `csrf-token` meta tag and cookies, so they work with a normal Rails session.

## JSON API

All responses are JSON. Errors: `403 {"error":"forbidden"}`, `404 {"error":"not_found"}`,
`422 {"errors":{"title":["can't be blank"]}}`.

| Method | Path | |
| --- | --- | --- |
| GET | `/me` | Current user, permissions, statuses, priorities, assignees (managers) |
| GET | `/tickets?status=active\|all\|open\|...&page=&per=` | List (`active` by default, max 100 per page) |
| POST | `/tickets` | `{ ticket: { title, body, priority, context, screenshot } }` — screenshot as data URL or multipart file |
| GET | `/tickets/:id` | Ticket with context and messages |
| PATCH | `/tickets/:id` | `{ ticket: { status, priority, assignee_id } }` — managers |
| POST | `/tickets/:id/close`, `/tickets/:id/reopen` | Managers |
| POST | `/tickets/:id/messages` | `{ message: { body, internal } }` |
| GET | `/tickets/:id/screenshot` | The image, with the same permissions as the ticket |

## Ruby API

```ruby
ticket = Trailticket.open_ticket(
  author: current_user,
  title: "Import failed",
  body: "The CSV import stopped at row 120",
  context: { page: { url: request.url } },  # same shape as the collector's
  screenshot: params[:screenshot],          # data URL or uploaded file, optional
  subject: current_account,                 # optional polymorphic link
  page_url: request.referer,                # optional, cleaned; overrides context.page.url
  metadata: { myapp: { plan: "pro" } }      # optional, stored as-is in context
)
ticket.persisted? # => true / false with ticket.errors

Trailticket::Ticket.active.where(assignee: current_admin)
Trailticket::TicketPolicy.new(current_admin, ticket).manage?
```

`metadata` is trusted server data: it skips the sanitizer and is merged into `ticket.context`
with string keys. It cannot use the reserved keys `page`, `trail`, `fields` or `errors`
(raises `ArgumentError`).

To clean a URL the same way the server does:

```ruby
Trailticket::ContextSanitizer.clean_url("https://app.test/r?token=abc")
# => "https://app.test/r?token=%5BFILTERED%5D"
```

## Web interface

A ready-made interface for whoever handles tickets: a **kanban** (drag cards between status
columns), a **list** with search, filters and pagination, and a **ticket page** with the
description, origin URL, navigation trail, the rest of the captured context and the ticket's
**history**, where the team can also **reply** or add **internal notes**.

It is a separate engine, so it can sit behind its own authentication while the API stays
available to every user:

```ruby
# config/routes.rb
mount Trailticket::Engine => "/trailticket"            # API used by the collector (all users)

authenticate :user, ->(user) { user.staff? } do         # Devise
  mount Trailticket::Web => "/admin/tickets"            # web interface (staff only)
end
```

```ruby
# config/initializers/trailticket.rb
Trailticket.configure do |c|
  # Required: the interface denies everyone until this returns true.
  c.authorize = ->(request) { request.env["warden"].user&.staff? }

  # Who is acting; stored as closed_by when a ticket reaches the final status.
  c.current_actor = ->(request) { request.env["warden"].user }

  # How authors and subjects (polymorphic) are shown.
  c.author_label  = ->(user) { user.name }
  c.subject_label = ->(record) { record.try(:name) || "#{record.class.name} ##{record.id}" }

  # Board columns, in order; where new tickets start; which ones mean "done".
  c.statuses       = %w[novo em_andamento aguardando resolvido cancelado]
  c.initial_status = "novo"
  c.final_statuses = %w[resolvido cancelado]

  # Final columns only show tickets closed in the last N days (nil: all).
  c.board_closed_days = 7

  # Triage: new tickets wait in initial_status without a priority until the team sets one.
  c.triage = true

  # Called on every status change, from the board, the ticket page, the API or your code.
  # actor is who made it (nil when unknown); (ticket, from, to) also works.
  c.on_status_changed = lambda do |ticket, from, to, actor|
    TicketMailer.status(ticket, from, to, actor).deliver_later
  end

  # Optional: a partial of yours, rendered on the ticket page with a `ticket` local.
  c.context_partial = "admin/tickets/context"
end
```

| Option | Default | |
| --- | --- | --- |
| `authorize` | denies all | `->(request) { bool }` who may use the interface |
| `current_actor` | `nil` | `->(request) { record }` stored as `closed_by` when closing |
| `author_label` | `"Class #id"` | `->(record) { String }` |
| `subject_label` | `"Class #id"` | `->(record) { String }` |
| `statuses` | `open in_progress waiting closed` | Columns, in order |
| `initial_status` | first of `statuses` | Where new tickets start |
| `final_statuses` | last of `statuses` | "Done" statuses; only these can be archived |
| `board_closed_days` | `7` | Final columns show tickets closed in the last N days; `nil` shows all |
| `triage` | `false` | See *Triage* below |
| `on_status_changed` | `nil` | `->(ticket, from, to, actor)`, after commit |
| `context_partial` | `nil` | Partial rendered on the ticket page with `ticket` |

The interface does not use `can_open`/`can_manage`, `current_user_method` or
`parent_controller`: those are for the JSON API. Its controllers inherit from
`ActionController::Base`, with their own layout, CSS and JS served by the engine — nothing
from your app's layout, asset pipeline, importmap, Hotwire or CSS framework is needed, and it
works under a CSP without `unsafe-inline`.

- **Status changes** are `PATCH` requests with the CSRF token. Moving into a final status
  fills `closed_at` and `closed_by`; moving back to a non-final one clears both (moving between
  final statuses keeps them). An invalid status returns 422 and
  nothing is saved. On the ticket page there are buttons for each status, so it also works
  without drag and drop (keyboard, touch screens).
- **Triage** (`c.triage = true`): tickets open in `initial_status` (e.g. "em_analise")
  **without a priority**; what the user picked when opening is kept as `suggested_priority` and
  shown as "No priority (suggested: High)". Someone sets the priority (and assignee) on the
  ticket page, and only then can it move to a non-final status — from the board, the buttons,
  the JSON API or your code (it fails with a clear message otherwise). Going straight to a final
  status, e.g. cancelled, is allowed. Work columns are ordered by priority, then oldest first.
  ```ruby
  c.statuses       = %w[em_analise a_fazer em_execucao aguardando resolvido cancelado]
  c.initial_status = "em_analise"
  c.final_statuses = %w[resolvido cancelado]
  c.triage         = true
  ```
  Name your statuses in your locale: `pt-BR.trailticket.statuses.em_analise: "Em análise"`.
- **Priority and assignee** can be set on the ticket page (assignees come from
  `config.assignees`, or just yourself). Both go to the history.
- **Keeping the board short**: final columns only show tickets closed in the last
  `board_closed_days` days, and tickets in a final status can be **archived** (button on the
  card and on the ticket page) to take them off the board and the default list. The list has an
  "Archived" filter to find them, and they can be unarchived; reopening an archived ticket
  unarchives it. Archiving is recorded in the history.
- **History**: the ticket page shows, in order, when it was opened, every status move
  (including close/reopen), priority and assignee change with who did it, and every reply and
  internal note. Changes are recorded in `trailticket_events` in the same transaction as the
  change, whether they come from the interface (`current_actor`), the JSON API (the signed-in
  user) or your own code — wrap it to record who did it:
  ```ruby
  Trailticket.with_actor(current_user) { ticket.update!(priority: "urgent") }
  ```
  Without an actor the entry shows "Someone".
- **Replies and internal notes** are written by `current_actor` (required; without it the form
  shows an error). Internal notes are never shown to the ticket's author through the API.
  `on_message_created` runs for both.
- **Safety**: all text is escaped; URLs only become links when they are `http`/`https`
  (`javascript:` and others are shown as text); field values are shown exactly as the
  sanitizer stored them.
- **Translations**: English and Brazilian Portuguese are included (`trailticket.web.*`,
  `trailticket.statuses.*`, `trailticket.priorities.*`). Add your own locale file to translate
  further or to name custom statuses.
- **Customizing views**: copy any template from the gem's
  `web/app/views/trailticket/panel/` to the same path in your app's `app/views/` to override it.

### Seeing it locally

The dummy app in `spec/dummy` mounts the interface at `/chamados` with ~15 sample tickets:

```bash
docker compose run --rm -p 3000:3000 devcontainer bin/dummy
# open http://localhost:3000/chamados
```

Data lives in `spec/dummy/db/development.sqlite3`; delete it to start over.

## Versioning

[SemVer](https://semver.org). Point your apps at a tag; an app only gets changes when you
bump its tag. To release:

1. Bump `lib/trailticket/version.rb` and add an entry to `CHANGELOG.md`
2. Commit, then `git tag -a v0.3.0 -m "v0.3.0" && git push --follow-tags`
   (annotated tag: `--follow-tags` does not push lightweight ones)
3. In each app: update the tag, `bundle update trailticket`, then
   `bin/rails trailticket:install:migrations && bin/rails db:migrate` if there are new migrations
   (0.3.0 adds `trailticket_events`, for the ticket history; 0.4.0 adds `archived_at`;
   0.5.0 makes `priority` nullable and adds `suggested_priority`).
   **Don't skip `install:migrations`**: updating the gem does not copy its migrations, so the app
   does not even see them as pending — and the board, the list and ticket updates fail until
   they run. Commit the copied migrations with the tag bump.

## Development

Everything runs in Docker; nothing needs to be installed on the host.

```bash
docker compose up -d                 # builds the image and installs gems
docker compose exec devcontainer bash
rspec                                # or: bundle exec rspec
rubocop                              # or: bundle exec rubocop
```

You can also use VS Code/Cursor: "Dev Containers: Reopen in Container".

Specs run against a dummy app in `spec/dummy`. To browse the web interface with sample data,
see [Seeing it locally](#seeing-it-locally).

## License

MIT.
