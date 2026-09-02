require "test_helper"

class OrderWorkTest < ActiveSupport::TestCase
  setup do
    @mechanic = users(:andrii)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: users(:owner),
                           mechanic: @mechanic, accepted_at: Time.current, status: :intake)
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

  test "mechanic_id is snapshotted at creation and does not follow a later reassignment" do
    work = @order.order_works.create!(name: "Робота", quantity: 1, price: 100)
    assert_equal @mechanic.id, work.mechanic_id

    other = User.create!(name: "Інший", email_address: "other@fixtures.test", password: "password123",
                         role: :mechanic, payroll_percent: 20, active: true)
    @order.update!(mechanic: other)

    assert_equal @mechanic.id, work.reload.mechanic_id,
      "an existing line keeps whoever was assigned when it was added"
    assert_equal other.id, @order.order_works.create!(name: "Друга робота", quantity: 1, price: 100).mechanic_id
  end

  # Without a mechanic the line is created with mechanic_id nil, counts toward
  # nobody's payroll until close backfills it, and makes the mechanic card read
  # «Послуги: 0 грн» for an order that plainly has services. Refuse it instead.
  test "a work line is refused while the order has no mechanic assigned" do
    @order.update!(mechanic: nil)

    work = @order.order_works.new(name: "Робота", quantity: 1, price: 100)

    assert_not work.valid?
    assert_includes work.errors[:base], "Спочатку призначте механіка замовлення"
  end

  # Only on create — clearing the mechanic later must not freeze the inline
  # quantity/price fields on lines that already exist.
  test "an existing line still saves after the order's mechanic is cleared" do
    work = @order.order_works.create!(name: "Робота", quantity: 1, price: 100)
    @order.update!(mechanic: nil)

    assert work.reload.update(quantity: 2)
    assert_equal 200, work.reload.total
  end
end
