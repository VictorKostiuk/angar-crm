require "test_helper"

class ClientsNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @client = clients(:ivan)
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  def order_for(status:, works:)
    order = Order.create!(client: @client, bike: bikes(:trek), accepted_by: @owner, mechanic: users(:andrii),
                          accepted_at: Time.current, status: status,
                          cancel_reason: (status == :cancelled ? "передумав" : nil))
    order.order_works.create!(name: "Послуга", quantity: 1, price: works)
    order.reload
  end

  # The row was only reachable through the name, which reads as plain text.
  test "each client row has an explicit link to the card" do
    get clients_path

    assert_response :success
    assert_select "tbody tr:first-of-type a[href=?][title=?]", client_path(@client), "Відкрити картку" do
      assert_select "svg"
    end
  end

  test "the card totals the client's orders and leaves cancelled ones out" do
    order_for(status: :in_progress, works: 700)
    order_for(status: :closed, works: 1300)
    order_for(status: :cancelled, works: 9999)

    get client_path(@client)

    assert_response :success
    assert_select "tfoot td", text: /Разом за 2 замовлення/
    assert_select "tfoot td", text: /скасовані не враховані/
    assert_select "tfoot td", text: "2 000 грн"
  end

  test "with nothing cancelled the note is not shown" do
    order_for(status: :closed, works: 500)

    get client_path(@client)

    assert_select "tfoot td", text: /Разом за 1 замовлення/
    assert_select "tfoot td", text: /скасовані не враховані/, count: 0
    assert_select "tfoot td", text: "500 грн"
  end
end
