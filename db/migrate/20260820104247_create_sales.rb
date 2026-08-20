class CreateSales < ActiveRecord::Migration[8.1]
  def change
    create_table :sales do |t|
      t.references :sold_by, null: false, foreign_key: { to_table: :users }
      t.references :client, foreign_key: true
      t.datetime :sold_at, null: false
      t.decimal :total, precision: 12, scale: 2, null: false, default: 0
      t.string :note

      t.timestamps
    end

    create_table :sale_items do |t|
      t.references :sale, null: false, foreign_key: true
      t.references :part, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :quantity, null: false, default: 1
      t.decimal :price, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total, precision: 12, scale: 2, null: false, default: 0

      t.timestamps
    end

    # A separate rate from payroll_percent: labour and retail margin are
    # different things and the shop sets them independently (D40).
    add_column :users, :sales_percent, :decimal, precision: 5, scale: 2, null: false, default: 0

    add_index :sales, :sold_at
  end
end
