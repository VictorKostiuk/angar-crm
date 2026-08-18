class CreateOrderWorks < ActiveRecord::Migration[8.1]
  def change
    create_table :order_works do |t|
      t.references :order, null: false, foreign_key: true
      t.references :service, foreign_key: true
      t.references :mechanic, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.decimal :quantity, precision: 8, scale: 2, null: false, default: 1
      t.decimal :price, precision: 12, scale: 2, null: false
      t.decimal :total, precision: 12, scale: 2, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
