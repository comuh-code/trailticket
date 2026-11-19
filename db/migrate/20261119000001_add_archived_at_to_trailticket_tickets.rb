class AddArchivedAtToTrailticketTickets < ActiveRecord::Migration[7.1]
  def change
    add_column :trailticket_tickets, :archived_at, :datetime
    add_index :trailticket_tickets, :archived_at
  end
end
