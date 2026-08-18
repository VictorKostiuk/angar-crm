require "test_helper"

class SupplierTest < ActiveSupport::TestCase
  test "requires a name" do
    supplier = Supplier.new
    assert_not supplier.valid?
    assert_includes supplier.errors[:name], "не може бути порожнім"
  end

  test "active scope returns only active suppliers" do
    assert_includes Supplier.active, suppliers(:shimano)
    assert_not_includes Supplier.active, suppliers(:archived)
  end
end
