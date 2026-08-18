class CreateDiscounts < ActiveRecord::Migration[8.1]
  def change
    create_table :discounts do |t|
      t.string :name, null: false
      t.integer :kind, null: false, default: 0
      t.decimal :value, precision: 8, scale: 2, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
