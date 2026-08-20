require "test_helper"

class OrderEditingTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           accepted_at: Time.current, status: :in_progress, mechanic: @mechanic)
    @part = @order.order_parts.create!(name: "Ланцюг", quantity: 2, price: 100)
    @work = @order.order_works.create!(name: "Робота", quantity: 1, price: 300)

    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  def settle!(status)
    @order.update!(payment_status: :paid, payment_method: :cash) if status == :closed
    @order.update!(status: status, cancel_reason: ("передумав" if status == :cancelled))
  end

  # A <form> is not a legal child of <tr>. The HTML5 parser inserts it EMPTY and
  # leaves the inputs outside it, so requestSubmit() posted nothing at all and
  # editing quantity or price did nothing.
  test "each editable cell carries its own form with the input actually inside it" do
    get order_path(@order)

    # HTML5 parser, not HTML4 — libxml2 is lenient here and shows the old
    # markup as working when the browser does not.
    doc = Nokogiri::HTML5(response.body)

    %w[ order_parts_rows order_works_rows ].each do |tbody|
      inputs = doc.css("##{tbody} input[type=number]")
      assert_equal 2, inputs.size, "#{tbody} should offer quantity and price"

      inputs.each do |input|
        assert input.ancestors("form").any?,
          "#{tbody}: #{input['name']} parsed outside its form, so submitting sends nothing"
      end

      assert_equal 0, doc.css("##{tbody} tr > form").size,
        "#{tbody}: a <form> directly inside <tr> is emptied by the parser"
    end
  end

  test "changing a quantity or a price recalculates the order" do
    patch order_order_part_path(@order, @part), params: { order_part: { quantity: 5 } },
          headers: { "Accept" => "#{Mime[:turbo_stream]}, text/html" }
    assert_response :success
    assert_equal 500, @part.reload.total

    patch order_order_work_path(@order, @work), params: { order_work: { price: 450 } },
          headers: { "Accept" => "#{Mime[:turbo_stream]}, text/html" }
    assert_equal 450, @work.reload.total
    assert_equal 950, @order.reload.total
  end

  # Hiding a button is not a guard.
  %i[ closed cancelled ].each do |status|
    test "a #{status} order rejects every edit at the controller, not just in the view" do
      settle!(status)

      get order_path(@order)
      assert_select "a", text: "+ Додати запчастину", count: 0
      assert_select "#order_parts_rows input[type=number]", 0
      assert_select "select[name=?]", "order[mechanic_id]", count: 0

      assert_no_difference -> { @order.order_parts.count } do
        post order_order_parts_path(@order), params: { order_part: { name: "Нова", quantity: 1, price: 10 } }
        assert_redirected_to @order
      end

      patch order_order_part_path(@order, @part), params: { order_part: { price: 999 } }
      assert_redirected_to @order
      assert_equal 100, @part.reload.price

      assert_no_difference -> { @order.order_works.count } do
        delete order_order_work_path(@order, @work)
      end

      patch order_path(@order), params: { order: { discount: 500 } }
      assert_redirected_to @order
      assert_equal 0, @order.reload.discount

      get new_order_order_part_path(@order)
      assert_redirected_to @order

      # Payment is part of the settled record too — the button must be gone and
      # the endpoint must refuse, not just the button.
      assert_select "a", text: "Змінити оплату", count: 0
      assert_select "a", text: "Оплата", count: 0

      patch order_payment_path(@order), params: { payment_method: "card" },
            headers: { "Accept" => "#{Mime[:turbo_stream]}, text/html" }
      assert_response :unprocessable_entity
      assert_match "оплату змінити не можна", response.body
    end
  end

  # Closing/cancelling happens through a modal that streams the page back. The
  # add buttons live in the card headers and the inline fields in the tbodies —
  # neither was in that stream, so a just-closed order still looked editable
  # until a reload, even though the server already refused every edit.
  test "the refresh stream carries the line sections, not just the totals" do
    @order.update!(mechanic: @mechanic, status: :waiting_pickup,
                   payment_status: :paid, payment_method: :cash)

    patch order_closure_path(@order),
          headers: { "Accept" => "#{Mime[:turbo_stream]}, text/html, application/xhtml+xml" }

    assert_response :success
    %w[ order_works_header order_parts_header order_works_rows order_parts_rows ].each do |target|
      assert_select "turbo-stream[action=update][target=#{target}]", 1,
        "#{target} must be refreshed or it keeps looking editable"
    end
    assert_select "turbo-stream[target=order_works_header] template a", 0, "no add button on a closed order"
  end

  test "an open order still edits freely" do
    assert_difference -> { @order.order_parts.count }, 1 do
      post order_order_parts_path(@order), params: { order_part: { name: "Нова", quantity: 1, price: 10 } }
    end

    patch order_path(@order), params: { order: { discount: 50 } }
    assert_equal 50, @order.reload.discount
  end
end
