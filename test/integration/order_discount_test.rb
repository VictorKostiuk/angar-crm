require "test_helper"

class OrderDiscountTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           mechanic: users(:andrii), accepted_at: Time.current, status: :in_progress)
    @order.order_works.create!(name: "Заміна ланцюга", quantity: 1, price: 250)
    @order.order_parts.create!(name: "Ланцюг", quantity: 1, price: 950)

    @percent = Discount.create!(name: "Постійний клієнт", kind: :percentage, value: 10)
    @fixed = Discount.create!(name: "Промо", kind: :fixed_amount, value: 300)

    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  # The order stored only the computed amount, never which catalog entry
  # produced it, so the picker had nothing to re-select and always read
  # "Без знижки" even while the totals showed the discount applied.
  test "the picker shows the discount that was applied" do
    patch order_path(@order), params: { order: { discount: "120", discount_record_id: @percent.id } }

    get order_path(@order)

    assert_response :success
    assert_select "select option[value=?][selected]", @percent.id.to_s
    assert_select "select option[value=''][selected]", 0, "«Без знижки» must not be selected"
    assert_equal 120, @order.reload.discount
    assert_equal @percent, @order.discount_record
  end

  # The reported sequence: pick a discount, the form auto-submits, Turbo follows
  # the redirect and re-renders — and the select must come back showing the
  # choice, not reset to "Без знижки".
  test "the select survives the Turbo redirect the picker triggers" do
    get order_path(@order)
    assert_select "select[name=?] option[selected]", "order[discount_record_id]", 0

    patch order_path(@order),
          params: { order: { discount_record_id: @percent.id.to_s, discount: "120" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }
    assert_response :redirect

    follow_redirect!
    assert_select "select[name=?] option[value=?][selected]", "order[discount_record_id]", @percent.id.to_s
    assert_select "select[name=?] option[value=''][selected]", "order[discount_record_id]", 0
    assert_select "dd", text: "−120 грн"
  end

  # Changing the mechanic posts its own form; it must not blank the discount.
  test "editing another field on the page leaves the discount alone" do
    patch order_path(@order), params: { order: { discount_record_id: @percent.id.to_s, discount: "120" } }
    patch order_path(@order), params: { order: { mechanic_id: users(:andrii).id } }

    @order.reload
    assert_equal @percent, @order.discount_record
    assert_equal 120, @order.discount

    get order_path(@order)
    assert_select "select[name=?] option[value=?][selected]", "order[discount_record_id]", @percent.id.to_s
  end

  test "the totals still reflect the amount, whichever entry was chosen" do
    patch order_path(@order), params: { order: { discount: "300", discount_record_id: @fixed.id } }

    @order.reload
    assert_equal 300, @order.discount
    assert_equal 900, @order.total # 250 + 950 − 300

    get order_path(@order)
    assert_select "dd", text: "−300 грн"
  end

  test "clearing the discount clears the remembered entry too" do
    patch order_path(@order), params: { order: { discount: "120", discount_record_id: @percent.id } }
    patch order_path(@order), params: { order: { discount: "0", discount_record_id: "" } }

    @order.reload
    assert_equal 0, @order.discount
    assert_nil @order.discount_record_id

    get order_path(@order)
    assert_select "#order_discount_record_id option[selected]", 0, "nothing selected means «Без знижки», the first option"
  end

  # The association must live in the markup, not in a line of JS that copies the
  # choice into a hidden field: a stale cached controller silently dropped it
  # while the amount still saved, which is exactly how an applied discount ended
  # up reading "Без знижки".
  test "the select itself is the discount_record_id field" do
    get order_path(@order)

    assert_select "select[name=?]", "order[discount_record_id]"
    assert_select "input[name=?]", "order[discount_record_id]", 0, "the association must not depend on a JS-written field"
    # The amount is derived server-side now (D47) — the form must not post one,
    # or a stale figure would race the derivation.
    assert_select "[name=?]", "order[discount]", 0
  end

  # Submit exactly what the browser serializes from the rendered form — every
  # named control in it — rather than hand-built params.
  test "the rendered form round-trips the discount as the browser would submit it" do
    @percent.update!(applies_to: :all)
    get order_path(@order)

    form = Nokogiri::HTML5(response.body).css("form").find { |f| f.css("select[name='order[discount_record_id]']").any? }
    assert form, "the discount form must exist"

    payload = {}
    form.css("input[name], select[name]").each do |field|
      next if field["name"].in?([ "_method", "authenticity_token" ])
      payload[field["name"]] = field.name == "select" ? @percent.id.to_s : field["value"].to_s
    end
    payload["order[discount]"] = "120" # what the picker computes for 10% of 1200

    patch order_path(@order), params: Rack::Utils.parse_nested_query(payload.map { |k, v| "#{k}=#{CGI.escape(v)}" }.join("&"))

    @order.reload
    assert_equal @percent, @order.discount_record, "the association must survive a real form submission"
    assert_equal 120, @order.discount

    get order_path(@order)
    assert_select "select option[value=?][selected]", @percent.id.to_s
  end

  test "an archived discount still shows on the orders that used it" do
    patch order_path(@order), params: { order: { discount: "120", discount_record_id: @percent.id } }
    @percent.update!(active: false)

    get order_path(@order)

    assert_response :success
    assert_equal @percent, @order.reload.discount_record
    assert_equal 120, @order.discount

    # It is gone from the catalog but must stay selectable here, or the picker
    # would report "Без знижки" for every past order that used it.
    assert_select "select option[value=?][selected]", @percent.id.to_s
    assert_select "select option[value=?]", @fixed.id.to_s

    # ...and it must not come back as an option for orders that never used it.
    other = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                          accepted_at: Time.current, status: :in_progress)
    get order_path(other)
    assert_select "select option[value=?]", @percent.id.to_s, count: 0
  end
end
