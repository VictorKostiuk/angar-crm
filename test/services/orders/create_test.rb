require "test_helper"

class Orders::CreateTest < ActiveSupport::TestCase
  setup do
    @owner = users(:owner)
  end

  test "creates a brand-new client and a brand-new bike together with the order" do
    assert_difference [ "Client.count", "Bike.count", "Order.count" ], 1 do
      @order = Orders::Create.call(
        accepted_by: @owner,
        client_name: "Марія Коваль",
        client_phone: "0672345678",
        bike_name: "Giant Revolt, синій",
        problem: "Не тримає гальмо"
      )
    end

    assert @order.persisted?
    assert_equal @order.client_id, @order.client.id
    assert_equal @order.bike_id, @order.bike.id
    assert_equal "intake", @order.status
  end

  test "reuses an existing client and adds a new bike to them" do
    order1 = Orders::Create.call(accepted_by: @owner, client_id: clients(:ivan).id, bike_id: bikes(:trek).id, problem: "перше")

    assert_difference "Bike.count", 1 do
      assert_no_difference "Client.count" do
        @order2 = Orders::Create.call(accepted_by: @owner, client_id: clients(:ivan).id, bike_name: "Cube Aim", problem: "друге")
      end
    end

    assert @order2.persisted?
    assert_equal order1.client_id, @order2.client_id
    assert_equal 2, clients(:ivan).reload.bikes_count
  end

  test "rolls back everything when the new client is invalid, leaving no orphan bike or order" do
    assert_no_difference [ "Client.count", "Bike.count", "Order.count" ] do
      @order = Orders::Create.call(
        accepted_by: @owner,
        client_name: "Дубль",
        client_phone: clients(:ivan).phone,
        bike_name: "Якийсь велосипед",
        problem: "test"
      )
    end

    assert_not @order.persisted?
    assert_includes @order.client.errors[:phone], "вже використовується"
    assert_not Bike.exists?(name: "Якийсь велосипед")
  end

  test "rejects an existing client with no bike selected and no new bike name" do
    assert_no_difference [ "Bike.count", "Order.count" ] do
      @order = Orders::Create.call(accepted_by: @owner, client_id: clients(:ivan).id, problem: "no bike")
    end

    assert_not @order.persisted?
    assert_includes @order.bike.errors[:name], "не може бути порожнім"
  end
end
