class CreateTrailticketTickets < ActiveRecord::Migration[7.1]
  def change
    create_table :trailticket_tickets, id: primary_key_type do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.string :status, null: false, default: "open"
      t.string :priority, null: false, default: "normal"
      t.text :page_url
      t.json :context
      t.references :author, polymorphic: true, null: false, type: foreign_key_type,
                            index: { name: "idx_trailticket_tickets_on_author" }
      t.references :assignee, polymorphic: true, type: foreign_key_type,
                              index: { name: "idx_trailticket_tickets_on_assignee" }
      t.references :closed_by, polymorphic: true, type: foreign_key_type,
                               index: { name: "idx_trailticket_tickets_on_closed_by" }
      t.references :subject, polymorphic: true, type: foreign_key_type,
                             index: { name: "idx_trailticket_tickets_on_subject" }
      t.datetime :closed_at
      t.timestamps
    end

    add_index :trailticket_tickets, :status
    add_index :trailticket_tickets, :updated_at
  end

  private

  # Follows the app's primary key type (e.g. uuid). If your user table uses a
  # different key type, adjust the copied migration.
  def primary_key_type
    Rails.configuration.generators.options.dig(:active_record, :primary_key_type) || :primary_key
  end

  def foreign_key_type
    primary_key_type == :uuid ? :uuid : :bigint
  end
end
