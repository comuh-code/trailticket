# Trailticket

Headless support tickets for Rails that carry the user's context.

When a user reports a problem, the ticket arrives with **where they were and what they did**:
the page URL, a screenshot, the path they took through the app, the fields they filled in and
any JavaScript errors — with passwords, tokens, card numbers and other sensitive data masked
in the browser *and again* on the server.

Trailticket has no UI of its own. It gives you:

- a mountable **JSON API** (tickets, replies, internal notes, status, assignee, close/reopen),
- a **Ruby API** (`Trailticket.open_ticket`) and plain Active Record models,
- a dependency-free **JavaScript collector** that records context and talks to the API.

You build the screens with whatever your app already uses — Bootstrap, Tailwind, Hotwire, React.

Requires Rails 7.1+ and Ruby 3.1+. Screenshots need Active Storage.

## Installation

```ruby
# Gemfile — pin a tag so updates are deliberate
gem "trailticket", git: "https://github.com/comuh-code/trailticket.git", tag: "v0.1.0"
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
  subject: current_account                  # optional polymorphic link
)
ticket.persisted? # => true / false with ticket.errors

Trailticket::Ticket.active.where(assignee: current_admin)
Trailticket::TicketPolicy.new(current_admin, ticket).manage?
```

## Versioning

[SemVer](https://semver.org). Point your apps at a tag; an app only gets changes when you
bump its tag. To release:

1. Bump `lib/trailticket/version.rb` and add an entry to `CHANGELOG.md`
2. `git commit -am "Release v0.2.0" && git tag v0.2.0 && git push --follow-tags`
3. In each app: update the tag, `bundle update trailticket`, then
   `bin/rails trailticket:install:migrations && bin/rails db:migrate` if there are new migrations

## Development

Everything runs in Docker; nothing needs to be installed on the host.

```bash
docker compose up -d                 # builds the image and installs gems
docker compose exec devcontainer bash
rspec                                # or: bundle exec rspec
rubocop                              # or: bundle exec rubocop
```

You can also use VS Code/Cursor: "Dev Containers: Reopen in Container".

Specs run against a dummy app in `spec/dummy`.

## License

MIT.
