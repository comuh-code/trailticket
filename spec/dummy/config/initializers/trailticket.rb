# Example setup: members open tickets, agents handle them, guests have no access.
Trailticket.configure do |c|
  c.user_class = "Admin"
  c.current_user_method = :current_admin
  c.can_open = ->(admin) { %w[member agent].include?(admin.role) }
  c.can_manage = ->(admin) { admin.role == "agent" }
  c.assignees = -> { Admin.where(role: "agent").order(:name) }

  # Web interface. Tests send the "session" in a header (agents only); the local
  # server (bin/dummy) has no login, so it lets everyone in, acting as the first agent.
  dummy_admin = lambda do |request|
    if Rails.env.development?
      Admin.where(role: "agent").order(:id).first
    else
      Admin.find_by(id: request.headers["X-Admin-Id"])
    end
  end
  c.authorize = ->(request) { dummy_admin.call(request)&.role == "agent" }
  c.current_actor = dummy_admin
  c.author_label = ->(admin) { admin.name }
  c.subject_label = ->(record) { record.try(:name) || "#{record.class.name} ##{record.id}" }
  c.on_status_changed = lambda do |ticket, from, to|
    Rails.logger.info("[trailticket] ##{ticket.id} #{from} -> #{to}")
  end
end
