class CreateOrderParts < ActiveRecord::Migration[8.1]
  def change
    create_table :order_parts do |t|
      t.references :order, null: false, foreign_key: true
      t.references :part, foreign_key: true
      t.string :name, null: false
      t.integer :quantity, null: false, default: 1
      t.decimal :price, precision: 12, scale: 2, null: false
      t.decimal :total, precision: 12, scale: 2, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
