require "test_helper"

class OrderPaymentFlowTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           mechanic: users(:andrii), accepted_at: Time.current, status: :waiting_pickup)
    @order.order_works.create!(name: "Робота", quantity: 1, price: 250)

    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  # What Turbo actually sends when submitting a form.
  def turbo_headers
    { "Accept" => "#{Mime[:turbo_stream]}, text/html, application/xhtml+xml" }
  end

  # The payment form lives inside the #modal Turbo Frame, so a bare redirect
  # would only swap that frame back to empty and leave the page stale — the
  # user had to reload to see the order as paid.
  test "paying streams the refreshed totals panel back instead of only closing the modal" do
    patch order_payment_path(@order),
          params: { payment_method: "cash", receipt_number: "42" },
          headers: turbo_headers

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type

    assert_select "turbo-stream[action=update][target=order_totals]" do
      assert_select "template", html: /#{I18n.t("statuses.payment.paid")}/
      assert_select "template", html: /Змінити оплату/
    end
    assert_select "turbo-stream[action=update][target=flash] template", html: /Оплату зафіксовано/
    # Rendered even from the order page, where the target is absent — a break in
    # order_card would 500 the payment submit for board users.
    assert_select "turbo-stream[action=replace][target=board_card_#{@order.id}]" do
      assert_select "template", html: /#{@order.bike.name}/
    end
    assert_select "turbo-stream[action=update][target=modal]"

    assert @order.reload.paid?
    assert_equal "42", @order.receipt_number

    # The symptom that was reported: the page itself, freshly loaded, agrees.
    get order_path(@order)
    assert_select "#order_totals" do
      assert_select "a", text: "Змінити оплату"
      assert_select "span", text: /#{I18n.t("payment_methods.cash")}, чек №42/
    end
  end

  test "the order page and the workshop board both render the extracted totals panel" do
    get order_path(@order)
    assert_response :success
    assert_select "#order_totals a", text: "Оплата"

    get root_path
    assert_response :success
    assert_select "#board_card_#{@order.id}"
  end

  test "an invalid payment method still re-renders the modal form with the error" do
    patch order_payment_path(@order),
          params: { payment_method: "bitcoin" },
          headers: turbo_headers

    assert_response :unprocessable_entity
    assert_match "недійсне значення", response.body
    refute @order.reload.paid?
  end

  test "html fallback still redirects to the order" do
    patch order_payment_path(@order), params: { payment_method: "cash" }

    assert_redirected_to @order
    assert @order.reload.paid?

    # Flash renders as a toast in the fixed overlay container, not in the
    # document flow — so it never reflows the page under it.
    follow_redirect!
    assert_select "#flash.fixed > #notice", text: /Оплату зафіксовано/
  end
end
