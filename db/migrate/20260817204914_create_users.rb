class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.integer :role, null: false, default: 0
      t.decimal :payroll_percent, precision: 5, scale: 2, null: false, default: 0
      t.string :phone
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :users, :email_address, unique: true
    add_index :users, :role
  end
end
