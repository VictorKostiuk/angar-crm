require "test_helper"

class OrderTest < ActiveSupport::TestCase
  setup do
    @client = clients(:ivan)
    @bike = bikes(:trek)
    @owner = users(:owner)
  end

  test "totals recalculate through the full add/edit/delete line lifecycle" do
    order = Order.create!(client: @client, bike: @bike, accepted_by: @owner, accepted_at: Time.current, status: :intake)

    work1 = order.order_works.create!(name: "Робота 1", quantity: 1, price: 250)
    order.order_works.create!(name: "Робота 2", quantity: 2, price: 100)
    part1 = order.order_parts.create!(name: "Деталь 1", quantity: 3, price: 50)

    order.reload
    assert_equal 450, order.works_total # 250 + 2*100
    assert_equal 150, order.parts_total # 3*50
    assert_equal 600, order.total
    assert_equal order.order_works.sum(:total), order.works_total
    assert_equal order.order_parts.sum(:total), order.parts_total

    work1.update!(quantity: 3)
    order.reload
    assert_equal 950, order.works_total # 750 + 200

    part1.destroy!
    order.reload
    assert_equal 0, order.parts_total
    assert_equal 950, order.total
  end

  test "discount is subtracted from the total but never pushes it negative" do
    order = Order.create!(client: @client, bike: @bike, accepted_by: @owner, accepted_at: Time.current, status: :intake, discount: 10_000)
    order.order_works.create!(name: "Робота", quantity: 1, price: 250)

    order.reload
    assert_equal 0, order.total
  end

  test "bike must belong to the order's client" do
    other_client = Client.create!(name: "Інший клієнт", phone: "0501112233")

    order = Order.new(client: other_client, bike: @bike, accepted_by: @owner, accepted_at: Time.current, status: :intake)

    assert_not order.valid?
    assert_includes order.errors[:bike], "належить іншому клієнту"
  end

  test "intake status does not shadow ActiveRecord::Base.new" do
    assert_instance_of Order, Order.new
  end

  test "paid requires a payment method" do
    order = Order.new(client: @client, bike: @bike, accepted_by: @owner, accepted_at: Time.current, status: :intake, payment_status: :paid)

    assert_not order.valid?
    assert_includes order.errors[:payment_method], "не може бути порожнім"
  end

  test "unpaid does not require a payment method" do
    order = Order.new(client: @client, bike: @bike, accepted_by: @owner, accepted_at: Time.current, status: :intake)

    assert order.valid?
  end

  test "cancelled requires a reason" do
    order = Order.new(client: @client, bike: @bike, accepted_by: @owner, accepted_at: Time.current, status: :cancelled)

    assert_not order.valid?
    assert_includes order.errors[:cancel_reason], "не може бути порожнім"
  end
end
