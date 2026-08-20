class RemoveSaleItemPriceDefault < ActiveRecord::Migration[8.1]
  # With a default of 0 a new SaleItem renders its price field as "0.0", not
  # empty — so `price.blank?` was false and SaleItem#default_from_part never
  # substituted the part's price. Every sale where the seller didn't type a
  # price recorded 0 грн. The column stays NOT NULL; the before_validation
  # callback always fills it.
  def change
    change_column_default :sale_items, :price, from: 0, to: nil
  end
end
