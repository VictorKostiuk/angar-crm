require "test_helper"

class OrderWorkTest < ActiveSupport::TestCase
  setup do
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: users(:owner), accepted_at: Time.current, status: :intake)
  end

  test "a custom line (no catalog service) requires a name and a price" do
    work = @order.order_works.new(quantity: 1)

    assert_not work.valid?
    assert_includes work.errors[:name], "не може бути порожнім"
    assert_includes work.errors[:price], "має бути числом"
  end

  test "snapshots name and price from the catalog service when attached" do
    work = @order.order_works.create!(service: services(:chain_replacement), quantity: 1)

    assert_equal services(:chain_replacement).name, work.name
    assert_equal services(:chain_replacement).base_price, work.price
  end

  test "total is quantity times price, rounded to 2 decimal places" do
    work = @order.order_works.create!(name: "Дробова кількість", quantity: "1.5", price: "333.33")

    assert_equal BigDecimal("500.00"), work.total
  end

  test "mechanic_id defaults from the order's mechanic at creation time only, not live" do
    mechanic = users(:andrii)

    work = @order.order_works.create!(name: "Без механіка", quantity: 1, price: 100)
    assert_nil work.mechanic_id

    @order.update!(mechanic: mechanic)
    work.reload
    assert_nil work.mechanic_id, "existing lines must not silently pick up a mechanic assigned later"

    work2 = @order.order_works.create!(name: "Після призначення механіка", quantity: 1, price: 100)
    assert_equal mechanic.id, work2.mechanic_id
  end
end
