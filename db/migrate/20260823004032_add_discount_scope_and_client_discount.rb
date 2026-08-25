class AddDiscountScopeAndClientDiscount < ActiveRecord::Migration[8.1]
  def change
    # A discount can now apply to services, to parts, or to the whole order.
    add_column :discounts, :applies_to, :integer, null: false, default: 0

    # A discount pinned to a client, applied to their orders automatically.
    add_reference :clients, :discount, foreign_key: true, null: true

    # Which of the three candidates actually won, for display. Free text rather
    # than an enum because Orders::RecalculateTotals writes it with
    # update_columns, which bypasses enum casting.
    add_column :orders, :discount_source, :string
  end
end
