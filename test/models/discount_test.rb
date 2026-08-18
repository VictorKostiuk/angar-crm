require "test_helper"

class DiscountTest < ActiveSupport::TestCase
  test "requires a name" do
    discount = Discount.new(kind: :fixed_amount, value: 100)
    assert_not discount.valid?
    assert_includes discount.errors[:name], "не може бути порожнім"
  end

  test "requires a positive value" do
    discount = Discount.new(name: "Тест", kind: :fixed_amount, value: 0)
    assert_not discount.valid?
  end

  test "percentage value cannot exceed 100" do
    discount = Discount.new(name: "Тест", kind: :percentage, value: 150)
    assert_not discount.valid?
  end

  test "fixed_amount value can exceed 100" do
    discount = Discount.new(name: "Тест", kind: :fixed_amount, value: 500)
    assert discount.valid?
  end

  test "active scope returns only active discounts" do
    active = Discount.create!(name: "Активна", kind: :fixed_amount, value: 100)
    archived = Discount.create!(name: "Архівна", kind: :fixed_amount, value: 100, active: false)

    assert_includes Discount.active, active
    assert_not_includes Discount.active, archived
  end
end
