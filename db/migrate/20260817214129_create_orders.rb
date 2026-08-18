class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    execute "CREATE SEQUENCE order_number_seq START 1"

    create_table :orders do |t|
      t.integer :number, null: false, default: -> { "nextval('order_number_seq')" }

      t.references :client, null: false, foreign_key: true
      t.references :bike, null: false, foreign_key: true
      t.references :mechanic, foreign_key: { to_table: :users }
      t.references :accepted_by, null: false, foreign_key: { to_table: :users }

      t.integer :status, null: false, default: 0
      t.text :problem
      t.text :comment

      t.datetime :accepted_at, null: false
      t.date :expected_ready_on
      t.datetime :closed_at
      t.datetime :cancelled_at
      t.text :cancel_reason

      t.integer :payment_status, null: false, default: 0
      t.datetime :paid_at
      t.integer :payment_method
      t.string :receipt_number

      t.decimal :works_total, precision: 12, scale: 2, null: false, default: 0
      t.decimal :parts_total, precision: 12, scale: 2, null: false, default: 0
      t.decimal :discount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total, precision: 12, scale: 2, null: false, default: 0

      t.timestamps
    end

    add_index :orders, :number, unique: true
    add_index :orders, :status
    add_index :orders, %i[ status accepted_at ]
    add_index :orders, :payment_status
    add_index :orders, :closed_at
  end
end
