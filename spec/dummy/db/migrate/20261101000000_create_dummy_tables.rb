# Tables of the dummy app itself. Tests build them in spec/support/schema.rb.
class CreateDummyTables < ActiveRecord::Migration[7.1]
  def change
    create_table :admins do |t|
      t.string :name
      t.string :role
    end

    create_table :communities do |t|
      t.string :name
    end
  end
end
