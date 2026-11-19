# frozen_string_literal: true

class AddTriageToTrailticketTickets < ActiveRecord::Migration[7.1]
  def change
    # With config.triage on, tickets start without a priority until the team sets one.
    change_column_null :trailticket_tickets, :priority, true
    change_column_default :trailticket_tickets, :priority, from: 'normal', to: nil
    add_column :trailticket_tickets, :suggested_priority, :string
  end
end
