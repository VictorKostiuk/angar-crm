class AddSaleItemRefToStockMovements < ActiveRecord::Migration[8.1]
  def change
    add_reference :stock_movements, :sale_item, foreign_key: true, null: true
  end
end
