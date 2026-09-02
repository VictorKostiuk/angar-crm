require "test_helper"

class Orders::CloseTest < ActiveSupport::TestCase
  setup do
    @client = clients(:ivan)
    @bike = bikes(:trek)
    @owner = users(:owner)
    @mechanic = users(:andrii)
    @order = Order.create!(client: @client, bike: @bike, accepted_by: @owner, accepted_at: Time.current, status: :waiting_pickup)
  end

  test "blocked when unpaid, no mechanic, or no lines" do
    assert_equal [
      "Замовлення не оплачено",
      "Не призначено механіка замовлення",
      "До замовлення не додано жодної послуги чи запчастини"
    ], Orders::Close.new(order: @order).blockers

    order = Orders::Close.call(order: @order)
    refute order.closed?
  end

  test "closes when paid, mechanic assigned, and at least one line exists" do
    @order.update!(mechanic: @mechanic, payment_status: :paid, payment_method: :cash)
    @order.order_works.create!(name: "Робота", quantity: 1, price: 250)

    order = Orders::Close.call(order: @order)

    assert order.closed?
    assert order.closed_at.present?
  end

  # OrderWork now refuses a line while the order has no mechanic, so nil can no
  # longer arise — but rows written before that guard existed still carry it,
  # and the backfill is what keeps them out of nobody's payroll. Built with
  # update_column because the model itself will not produce this state any more.
  test "backfills a legacy nil mechanic_id on a work line at close time" do
    @order.update!(mechanic: @mechanic, payment_status: :paid, payment_method: :cash)
    work = @order.order_works.create!(name: "Робота", quantity: 1, price: 250)
    work.update_column(:mechanic_id, nil)

    Orders::Close.call(order: @order)

    assert_equal @mechanic.id, work.reload.mechanic_id
  end

  test "does not overwrite an existing mechanic_id on a work line" do
    other_mechanic = User.create!(name: "Інший", email_address: "other@fixtures.test", password: "password123", role: :mechanic, payroll_percent: 20, active: true)
    @order.update!(mechanic: @mechanic, payment_status: :paid, payment_method: :cash)
    work = @order.order_works.create!(name: "Робота", quantity: 1, price: 250, mechanic: other_mechanic)

    Orders::Close.call(order: @order)

    assert_equal other_mechanic.id, work.reload.mechanic_id
  end

  test "double close does not overwrite closed_at, and does not double-consume stock" do
    part = parts(:kmc_chain)
    part.stock_movements.create!(user: @owner, kind: :receipt, quantity: 10)

    @order.update!(mechanic: @mechanic, payment_status: :paid, payment_method: :cash)
    @order.order_works.create!(name: "Робота", quantity: 1, price: 250)
    @order.order_parts.create!(part: part, quantity: 2)

    order = Orders::Close.call(order: @order)
    first_closed_at = order.closed_at
    assert_equal 8, part.reload.stock_quantity

    order = Orders::Close.call(order: order)

    assert_equal first_closed_at, order.closed_at
    assert_equal [ "Замовлення вже закрито або скасовано" ], Orders::Close.new(order: order).blockers
    assert_equal 8, part.reload.stock_quantity, "a repeat close must not consume stock a second time"
    assert_equal 1, StockMovement.where(part: part, kind: :consumption, order: order).count
  end

  test "consumes stock for catalog-linked parts only, not custom lines" do
    part = parts(:kmc_chain)
    part.stock_movements.create!(user: @owner, kind: :receipt, quantity: 5)

    @order.update!(mechanic: @mechanic, payment_status: :paid, payment_method: :cash)
    @order.order_parts.create!(part: part, quantity: 2)
    @order.order_parts.create!(name: "Нестандартна деталь", quantity: 1, price: 100) # no part_id

    Orders::Close.call(order: @order)

    assert_equal 3, part.reload.stock_quantity
  end

  test "closing does not block when stock would go negative" do
    part = parts(:kmc_chain)
    part.stock_movements.create!(user: @owner, kind: :receipt, quantity: 1)

    @order.update!(mechanic: @mechanic, payment_status: :paid, payment_method: :cash)
    @order.order_parts.create!(part: part, quantity: 5)

    order = Orders::Close.call(order: @order)

    assert order.closed?
    assert_equal(-4, part.reload.stock_quantity)
  end

  test "a $0 warranty order with at least one line can close" do
    @order.update!(mechanic: @mechanic, payment_status: :paid, payment_method: :cash)
    @order.order_works.create!(name: "Гарантійний ремонт", quantity: 1, price: 0)

    order = Orders::Close.call(order: @order)

    assert order.closed?
    assert_equal 0, order.total
  end
end
