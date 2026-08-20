class AllowCustomSaleItems < ActiveRecord::Migration[8.1]
  # A counter sale isn't always a catalogue item — mirrors the custom line the
  # order screen already allows. A line with no part is a one-off: it carries
  # its own name and price and never touches stock.
  def change
    change_column_null :sale_items, :part_id, true
  end
end
