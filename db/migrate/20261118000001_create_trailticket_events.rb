class CreateTrailticketEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :trailticket_events, id: primary_key_type do |t|
      t.references :ticket, null: false, type: foreign_key_type,
                            foreign_key: { to_table: :trailticket_tickets },
                            index: { name: "idx_trailticket_events_on_ticket" }
      t.references :actor, polymorphic: true, type: foreign_key_type,
                           index: { name: "idx_trailticket_events_on_actor" }
      t.string :action, null: false
      t.json :data
      t.datetime :created_at, null: false
    end
  end

  private

  def primary_key_type
    Rails.configuration.generators.options.dig(:active_record, :primary_key_type) || :primary_key
  end

  def foreign_key_type
    primary_key_type == :uuid ? :uuid : :bigint
  end
end
