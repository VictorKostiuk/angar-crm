class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.references :category, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :base_price, precision: 12, scale: 2, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :services, :name
    add_index :services, :active
  end
end
