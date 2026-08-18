class CreateBikes < ActiveRecord::Migration[8.1]
  def change
    create_table :bikes do |t|
      t.references :client, null: false, foreign_key: true
      t.string :name, null: false
      t.string :brand
      t.string :model
      t.string :color
      t.string :size
      t.text :notes
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :bikes, :active
  end
end
