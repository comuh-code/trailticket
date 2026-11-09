class CreateTrailticketMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :trailticket_messages, id: primary_key_type do |t|
      t.references :ticket, null: false, type: foreign_key_type,
                            foreign_key: { to_table: :trailticket_tickets },
                            index: { name: "idx_trailticket_messages_on_ticket" }
      t.references :author, polymorphic: true, null: false, type: foreign_key_type,
                            index: { name: "idx_trailticket_messages_on_author" }
      t.text :body, null: false
      t.boolean :internal, null: false, default: false
      t.timestamps
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
