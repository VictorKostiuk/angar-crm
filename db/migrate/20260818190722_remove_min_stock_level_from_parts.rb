class RemoveMinStockLevelFromParts < ActiveRecord::Migration[8.1]
  def change
    remove_column :parts, :min_stock_level, :integer, null: false, default: 0
  end
end
