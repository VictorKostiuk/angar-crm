class CreateSuppliers < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.string :name, null: false
      t.string :phone
      t.string :email
      t.text :notes
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
