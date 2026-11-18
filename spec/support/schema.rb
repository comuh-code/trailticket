# frozen_string_literal: true

# O banco de teste é SQLite em memória: monta o schema a cada execução.
ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
  create_table :admins, force: true do |t|
    t.string :name
    t.string :role
  end

  create_table :communities, force: true do |t|
    t.string :name
  end

  # The host app's own Message (spec/dummy/app/models/message.rb).
  create_table :messages, force: true do |t|
    t.string :text
  end
end

ActiveRecord::MigrationContext.new(
  [
    ActiveStorage::Engine.root.join('db/migrate').to_s,
    File.expand_path('../../db/migrate', __dir__)
  ]
).migrate
