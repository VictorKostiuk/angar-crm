class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.integer :kind, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :categories, %i[ kind name ], unique: true
  end
end
