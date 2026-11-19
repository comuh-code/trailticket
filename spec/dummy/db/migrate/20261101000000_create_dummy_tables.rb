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
