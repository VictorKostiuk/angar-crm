require "test_helper"

class OrderStatusChangeTest < ActiveSupport::TestCase
  setup do
    @order = Order.create!(
      client: clients(:ivan), bike: bikes(:trek), accepted_by: users(:owner),
      accepted_at: Time.current, status: :intake
    )
  end

  test "valid with from/to status and no comment" do
    change = @order.order_status_changes.new(user: users(:owner), from_status: "intake", to_status: "in_progress")
    assert change.valid?
  end

  test "requires from_status and to_status" do
    change = @order.order_status_changes.new(user: users(:owner))
    assert_not change.valid?
    assert_includes change.errors[:from_status], "не може бути порожнім"
    assert_includes change.errors[:to_status], "не може бути порожнім"
  end

  test "rejects a comment longer than 200 characters" do
    change = @order.order_status_changes.new(
      user: users(:owner), from_status: "intake", to_status: "in_progress", comment: "а" * 201
    )
    assert_not change.valid?
  end
end
