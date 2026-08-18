class AddSupplierAndPurchasePriceToParts < ActiveRecord::Migration[8.1]
  def change
    add_reference :parts, :supplier, null: true, foreign_key: true
    add_column :parts, :purchase_price, :decimal, precision: 12, scale: 2
    add_column :parts, :stock_quantity, :integer, null: false, default: 0
    add_column :parts, :min_stock_level, :integer, null: false, default: 0
  end
end
