class ChangeExpensesUserIdNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :expenses, :user_id, true
  end
end
