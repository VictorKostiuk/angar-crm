class CreateOrderStatusChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :order_status_changes do |t|
      t.references :order, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :from_status, null: false
      t.string :to_status, null: false
      t.string :comment

      t.timestamps
    end

    add_index :order_status_changes, :created_at
  end
end
