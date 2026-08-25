require "test_helper"

class Orders::ApplyDiscountTest < ActiveSupport::TestCase
  setup do
    @client = clients(:ivan)
    @order = Order.create!(client: @client, bike: bikes(:trek), accepted_by: users(:owner),
                           accepted_at: Time.current, status: :in_progress)
    @order.order_works.create!(name: "Послуга", quantity: 1, price: 2000)
    @order.order_parts.create!(name: "Запчастина", quantity: 1, price: 3000)
    @order.reload
  end

  def discount(value, applies_to, kind: :percentage, name: "З")
    Discount.create!(name: "#{name} #{value} #{applies_to}", kind: kind, value: value, applies_to: applies_to)
  end

  def apply!(record = nil)
    @order.update!(discount_record: record)
    @order.reload
  end

  # 2 000 послуги + 3 000 запчастини. 5% off services is 100, off everything 250
  # — the same discount against the wrong base is 2.5× out.
  test "the scope decides what the percentage comes off" do
    apply! discount(5, :services)
    assert_equal 100, @order.discount
    assert_equal 4900, @order.total

    apply! discount(5, :parts)
    assert_equal 150, @order.discount

    apply! discount(5, :all)
    assert_equal 250, @order.discount
  end

  # #026 carried a 10 000 грн discount on a 1 200 грн order, taking it to zero.
  test "a discount never exceeds the base it comes off" do
    apply! discount(10_000, :services, kind: :fixed_amount)

    assert_equal 2000, @order.discount, "capped at the services subtotal"
    assert_equal 3000, @order.total
  end

  test "a scoped discount on an order with nothing in that scope is zero" do
    @order.order_works.destroy_all
    apply! discount(500, :services, kind: :fixed_amount)

    assert_equal 0, @order.discount
    assert_equal 3000, @order.reload.total
  end

  # A percentage used to freeze as an amount at pick time.
  test "the discount re-derives when the lines change" do
    apply! discount(10, :services)
    assert_equal 200, @order.discount

    @order.order_works.create!(name: "Ще послуга", quantity: 1, price: 1000)
    assert_equal 300, @order.reload.discount, "10% of 3 000, not the old 200"
  end

  test "a discount pinned to the client applies with no manual pick" do
    @client.update!(discount: discount(5, :services))
    Orders::RecalculateTotals.call(@order)

    assert_equal 100, @order.reload.discount
    assert_equal "client", @order.discount_source
  end

  test "the client keeps whichever discount is worth more" do
    @client.update!(discount: discount(5, :services, name: "pinned"))

    apply! discount(10, :services, name: "manual")
    assert_equal 200, @order.discount, "the bigger manual one wins"
    assert_equal "manual", @order.discount_source

    apply! discount(2, :services, name: "small manual")
    assert_equal 100, @order.discount, "the pinned one wins when the manual is smaller"
    assert_equal "client", @order.discount_source
  end

  test "no discount anywhere leaves the order at full price" do
    Orders::RecalculateTotals.call(@order)

    assert_equal 0, @order.reload.discount
    assert_nil @order.discount_source
    assert_equal 5000, @order.total
  end
end
