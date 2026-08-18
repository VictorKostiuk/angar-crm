class CreateParts < ActiveRecord::Migration[8.1]
  def change
    create_table :parts do |t|
      t.references :category, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :base_price, precision: 12, scale: 2, null: false, default: 0
      t.string :sku
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :parts, :name
    add_index :parts, :active
  end
end
