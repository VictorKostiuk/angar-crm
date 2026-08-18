class CreatePayrollPayouts < ActiveRecord::Migration[8.1]
  def change
    create_table :payroll_payouts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :period_month, null: false
      t.string :note

      t.timestamps
    end
  end
end
