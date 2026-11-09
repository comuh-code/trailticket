Trailticket.configure do |c|
  # Who the user is and how to get the signed-in one.
  c.user_class = "User"
  c.current_user_method = :current_user
  # c.authenticate = -> { authenticate_user! }

  # Who may open tickets (and see their own).
  c.can_open = ->(user) { true }

  # Who handles tickets: sees all, replies, internal notes, status, assignee, close/reopen.
  c.can_manage = ->(user) { false }

  # Who can be assigned. Without it, managers can only assign themselves.
  # c.assignees = -> { User.where(role: %w[support]) }

  # How users appear in the API. Keep it minimal.
  # c.user_json = ->(user) { { id: user.id, name: user.name } }

  # Controller the engine inherits from ("ActionController::API" for API-only apps).
  c.parent_controller = "ApplicationController"

  # Hooks, run after commit.
  # c.on_ticket_created  = ->(ticket) { }
  # c.on_message_created = ->(message) { }
  # c.on_status_changed  = ->(ticket, from, to) { }

  # Context capture. Rails' filter_parameters are always applied too.
  # c.sensitive_fields += %w[birth_date]
  # c.capture_field_values = false   # keep only which fields were filled
  # c.max_screenshot_bytes = 5.megabytes
end
