# Example setup: members open tickets, agents handle them, guests have no access.
Trailticket.configure do |c|
  c.user_class = "Admin"
  c.current_user_method = :current_admin
  c.can_open = ->(admin) { %w[member agent].include?(admin.role) }
  c.can_manage = ->(admin) { admin.role == "agent" }
  c.assignees = -> { Admin.where(role: "agent").order(:name) }
end
