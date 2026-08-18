class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.string :category, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :description
      t.date :date, null: false
      t.references :user, null: false, foreign_key: true
      t.references :stock_movement, null: true, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end
