require "test_helper"

class OrderPartTest < ActiveSupport::TestCase
  setup do
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: users(:owner), accepted_at: Time.current, status: :intake)
  end

  test "a custom line (no catalog part) requires a name and a price" do
    part = @order.order_parts.new(quantity: 1)

    assert_not part.valid?
    assert_includes part.errors[:name], "не може бути порожнім"
    assert_includes part.errors[:price], "має бути числом"
  end

  test "snapshots name and price from the catalog part when attached" do
    part = @order.order_parts.create!(part: parts(:kmc_chain), quantity: 1)

    assert_equal parts(:kmc_chain).name, part.name
    assert_equal parts(:kmc_chain).base_price, part.price
  end

  test "quantity must be a positive integer" do
    part = @order.order_parts.new(name: "Дробова кількість", quantity: "1.5", price: 10)

    assert_not part.valid?
    assert_includes part.errors[:quantity], "має бути цілим числом"
  end
end
