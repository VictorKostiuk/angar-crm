require "test_helper"

class PartTest < ActiveSupport::TestCase
  setup do
    @category = categories(:chains)
  end

  test "purchase_price is optional but must not be negative when present" do
    part = Part.new(category: @category, name: "Тест", base_price: 100, purchase_price: -1)
    assert_not part.valid?
    assert part.errors[:purchase_price].present?

    part.purchase_price = nil
    assert part.valid?
  end

  test "min_stock_level defaults to 0 and rejects negative values" do
    part = Part.create!(category: @category, name: "Тест", base_price: 100)
    assert_equal 0, part.min_stock_level

    part.min_stock_level = -1
    assert_not part.valid?
  end

  test "low_stock? and the low_stock scope agree on stock_quantity <= min_stock_level" do
    low = Part.create!(category: @category, name: "Мало", base_price: 100, stock_quantity: 1, min_stock_level: 2)
    ok = Part.create!(category: @category, name: "Достатньо", base_price: 100, stock_quantity: 5, min_stock_level: 2)

    assert low.low_stock?
    assert_not ok.low_stock?
    assert_includes Part.low_stock, low
    assert_not_includes Part.low_stock, ok
  end

  test "a part with no threshold set (min_stock_level: 0) is never low stock, even at zero quantity" do
    untouched = Part.create!(category: @category, name: "Без порогу", base_price: 100)
    assert_equal 0, untouched.stock_quantity
    assert_equal 0, untouched.min_stock_level

    assert_not untouched.low_stock?
    assert_not_includes Part.low_stock, untouched
  end
end
