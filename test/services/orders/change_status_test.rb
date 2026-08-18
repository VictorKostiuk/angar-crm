require "test_helper"

class Orders::ChangeStatusTest < ActiveSupport::TestCase
  setup do
    @client = clients(:ivan)
    @bike = bikes(:trek)
    @owner = users(:owner)
    @order = Order.create!(client: @client, bike: @bike, accepted_by: @owner, accepted_at: Time.current, status: :intake)
  end

  test "moves between open statuses and logs the change" do
    order = Orders::ChangeStatus.call(order: @order, status: :in_progress, user: @owner, comment: "Взяли в роботу")

    assert order.errors.empty?
    assert order.in_progress?

    change = order.order_status_changes.last
    assert_equal "intake", change.from_status
    assert_equal "in_progress", change.to_status
    assert_equal "Взяли в роботу", change.comment
    assert_equal @owner, change.user
  end

  test "closed is not reachable through change status" do
    order = Orders::ChangeStatus.call(order: @order, status: :closed, user: @owner)

    assert order.errors[:status].present?
    assert order.intake?
    assert_equal 0, order.order_status_changes.count
  end

  test "cancelled is not reachable through change status" do
    order = Orders::ChangeStatus.call(order: @order, status: :cancelled, user: @owner)

    assert order.errors[:status].present?
    assert order.intake?
  end

  test "refuses to change status on an already closed order" do
    @order.update!(mechanic: @owner, payment_status: :paid, payment_method: :cash)
    @order.order_works.create!(name: "Робота", quantity: 1, price: 100)
    Orders::Close.call(order: @order)
    assert @order.closed?

    order = Orders::ChangeStatus.call(order: @order, status: :in_progress, user: @owner)

    assert order.errors[:status].present?
    assert order.closed?
  end

  test "submitting the same status is a no-op and is not logged" do
    order = Orders::ChangeStatus.call(order: @order, status: :intake, user: @owner, comment: "не змінилося")

    assert order.errors.empty?
    assert_equal 0, order.order_status_changes.count
  end

  test "rejects a comment longer than 200 characters and leaves the status unchanged" do
    order = Orders::ChangeStatus.call(order: @order, status: :in_progress, user: @owner, comment: "а" * 201)

    assert order.errors[:base].present?
    order.reload
    assert order.intake?
    assert_equal 0, order.order_status_changes.count
  end
end
