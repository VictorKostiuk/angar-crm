class CreateStockMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_movements do |t|
      t.references :part, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.references :order, null: true, foreign_key: true
      t.integer :kind, null: false
      t.integer :quantity, null: false
      t.string :note

      t.timestamps
    end
  end
end
