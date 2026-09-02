require "test_helper"

class Clients::LoyaltyTierTest < ActiveSupport::TestCase
  setup do
    @client = clients(:ivan)
    @owner = users(:owner)
  end

  # Spend counts only once the order is closed — the money has to be realised.
  def close_order!(works:, parts: 0)
    order = Order.create!(client: @client, bike: bikes(:trek), accepted_by: @owner,
                          accepted_at: Time.current, status: :in_progress, mechanic: users(:andrii))
    order.order_works.create!(name: "Послуга", quantity: 1, price: works, mechanic: users(:andrii))
    order.order_parts.create!(name: "Запчастина", quantity: 1, price: parts) if parts.positive?
    order.update!(payment_status: :paid, payment_method: :cash)
    Orders::Close.call(order: order)
  end

  def new_order_with(works:, parts: 0)
    order = Order.create!(client: @client, bike: bikes(:trek), accepted_by: @owner,
                          accepted_at: Time.current, status: :in_progress, mechanic: users(:andrii))
    order.order_works.create!(name: "Послуга", quantity: 1, price: works)
    order.order_parts.create!(name: "Запчастина", quantity: 1, price: parts) if parts.positive?
    order.reload
  end

  test "the tier boundaries are exact" do
    assert_equal 0,  Clients::LoyaltyTier.percent_for(0)
    assert_equal 0,  Clients::LoyaltyTier.percent_for(14_999)
    assert_equal 5,  Clients::LoyaltyTier.percent_for(15_000)
    assert_equal 5,  Clients::LoyaltyTier.percent_for(19_999)
    assert_equal 10, Clients::LoyaltyTier.percent_for(20_000)
    assert_equal 10, Clients::LoyaltyTier.percent_for(50_000)
  end

  # Parts are goods, not our work — they must not push a client up a tier.
  test "only services count toward the threshold" do
    close_order!(works: 10_000, parts: 40_000)

    assert_equal 10_000, @client.services_spent
    assert_equal 0, @client.loyalty_percent
  end

  test "an open order does not count until it is closed" do
    new_order_with(works: 16_000)

    assert_equal 0, @client.services_spent
    assert_equal 0, @client.loyalty_percent
  end

  test "crossing 15k earns 5% off services automatically, with nothing picked" do
    close_order!(works: 15_000)
    assert_equal 5, @client.reload.loyalty_percent

    order = new_order_with(works: 2000, parts: 3000)

    assert_nil order.discount_record, "nothing was picked by hand"
    assert_equal 100, order.discount, "5% of 2 000 послуги, not of 5 000"
    assert_equal "loyalty", order.discount_source
    assert_equal 4900, order.total
  end

  test "crossing 20k earns 10%" do
    close_order!(works: 20_000)

    order = new_order_with(works: 2000)
    assert_equal 200, order.discount
    assert_equal "loyalty", order.discount_source
  end

  # Best for the client, whichever way round it falls.
  test "loyalty and a pinned discount take whichever is worth more" do
    close_order!(works: 20_000) # 10%
    @client.update!(discount: Discount.create!(name: "5%", kind: :percentage, value: 5, applies_to: :services))

    order = new_order_with(works: 2000)
    assert_equal 200, order.discount, "loyalty 10% beats the pinned 5%"
    assert_equal "loyalty", order.discount_source

    @client.update!(discount: Discount.create!(name: "20%", kind: :percentage, value: 20, applies_to: :services))
    Orders::RecalculateTotals.call(order)
    assert_equal 400, order.reload.discount, "the pinned 20% beats loyalty 10%"
    assert_equal "client", order.discount_source
  end

  test "it reports what the client is working toward" do
    assert_equal [ 15_000, 5 ], Clients::LoyaltyTier.next_tier_for(0)
    assert_equal [ 20_000, 10 ], Clients::LoyaltyTier.next_tier_for(15_000)
    assert_nil Clients::LoyaltyTier.next_tier_for(20_000)
  end
end
