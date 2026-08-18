require "test_helper"

class StockMovementTest < ActiveSupport::TestCase
  setup do
    @part = parts(:kmc_chain)
    @user = users(:owner)
  end

  test "quantity must be a nonzero integer" do
    movement = StockMovement.new(part: @part, user: @user, kind: :receipt, quantity: 0)
    assert_not movement.valid?

    movement.quantity = 5
    assert movement.valid?
  end

  test "recalculates the part's stock_quantity as the sum of its movements" do
    @part.stock_movements.create!(user: @user, kind: :receipt, quantity: 10)
    assert_equal 10, @part.reload.stock_quantity

    @part.stock_movements.create!(user: @user, kind: :write_off, quantity: -3)
    assert_equal 7, @part.reload.stock_quantity
  end

  test "user is optional (system-generated consumption has no user)" do
    movement = StockMovement.new(part: @part, kind: :consumption, quantity: -1)
    assert movement.valid?
  end
end
