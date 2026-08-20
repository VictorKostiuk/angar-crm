class AddDiscountRefToOrders < ActiveRecord::Migration[8.1]
  def change
    # orders.discount stores the computed *amount*; which catalog Discount
    # produced it was never recorded, so the picker on the order page had
    # nothing to re-select and always fell back to "Без знижки".
    add_reference :orders, :discount_record, foreign_key: { to_table: :discounts }, null: true
  end
end
