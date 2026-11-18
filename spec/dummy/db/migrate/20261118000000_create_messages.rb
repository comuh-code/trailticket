# The dummy app's own messages table (see app/models/message.rb).
class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.string :text
    end
  end
end
