class AddPaidOnToPayrollPayouts < ActiveRecord::Migration[8.1]
  def up
    add_column :payroll_payouts, :paid_on, :date

    # period_month says which month's earnings a payout settles; paid_on says
    # when the money actually left. Rows written before this column existed
    # only have created_at, which is the closest record of that.
    execute "UPDATE payroll_payouts SET paid_on = created_at::date WHERE paid_on IS NULL"

    change_column_null :payroll_payouts, :paid_on, false
    add_index :payroll_payouts, :paid_on
  end

  def down
    remove_column :payroll_payouts, :paid_on
  end
end
