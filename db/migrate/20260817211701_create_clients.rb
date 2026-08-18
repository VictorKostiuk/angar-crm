class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.string :name, null: false
      t.string :phone, null: false
      t.string :email
      t.string :city
      t.text :notes
      t.integer :bikes_count, null: false, default: 0
      t.integer :orders_count, null: false, default: 0

      t.timestamps
    end

    add_index :clients, :phone, unique: true
    add_index :clients, :name
  end
end
