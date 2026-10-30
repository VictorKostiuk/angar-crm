require "test_helper"

# D71: «Швидкий сервіс» — a short job entered from Майстерня in one form
# (mechanic, services, materials) and closed on the spot, with no client or
# bike. It is a real closed order, so payroll, stock and Фінанси count it.
class QuickServiceTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii)
    @service = services(:chain_replacement)
    @part = parts(:kmc_chain)
    StockMovement.create!(part: @part, kind: :receipt, quantity: 5, user: @owner)
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  def stream_headers
    { "Accept" => "#{Mime[:turbo_stream]}, text/html, application/xhtml+xml" }
  end

  def quick!(mechanic_id: @mechanic.id, works: { "0" => { service_id: @service.id, quantity: 1 } },
             parts: { "0" => { part_id: @part.id, quantity: 1 } }, headers: {})
    post quick_services_path, headers: headers,
         params: { order: { mechanic_id: mechanic_id, comment: "Підкачав колеса",
                            order_works_attributes: works, order_parts_attributes: parts } }
  end

  test "the workshop page opens the quick-service form in the modal" do
    sign_in(@mechanic)

    get root_path
    assert_select "a[href=?][data-turbo-frame=modal]", new_quick_service_path, text: "+ Швидкий сервіс"

    get new_quick_service_path
    assert_response :success
    assert_select "select[name='order[mechanic_id]'] option[selected][value=?]", @mechanic.id.to_s
    assert_select "select[name='order[order_works_attributes][0][service_id]']"
    assert_select "select[name='order[order_parts_attributes][0][part_id]']"
    assert_select "input[name='order[payment_method]']", 0, "paid on the spot, nobody is asked how"
  end

  test "a quick service is recorded paid and closed, with no client or bike" do
    sign_in(@owner)

    assert_difference -> { Order.count }, 1 do
      assert_difference -> { @part.reload.stock_quantity }, -1 do
        quick!
      end
    end

    order = Order.order(:id).last
    assert_redirected_to root_path
    assert_equal "Швидкий сервіс #{format('#%03d', order.number)} записано — 1 200 грн.", flash[:notice]
    assert order.quick?
    assert order.closed?
    assert order.paid?
    assert_nil order.payment_method
    assert_nil order.client
    assert_nil order.bike
    assert_equal @mechanic, order.mechanic
    assert_equal @owner, order.accepted_by
    assert_equal "Підкачав колеса", order.comment
    assert_equal [ [ "Заміна ланцюга", 250 ] ], order.order_works.map { [ it.name, it.price ] }, "name and price from the price list"
    assert_equal [ @mechanic.id ], order.order_works.map(&:mechanic_id)
    assert_equal 950, order.parts_total
    assert StockMovement.where(order: order, kind: :consumption).exists?, "a catalogue material leaves stock like on any order"
  end

  # It counts toward the mechanic's pay exactly like a regular order — which
  # includes the D37 per-order minimum: 35% of 250 is 88, paid as 100.
  test "the mechanic's earnings include it" do
    sign_in(@owner)
    stats = -> { Reports::MechanicStats.new(range: Date.current.all_month).row_for(@mechanic) }
    assert_equal 0, stats.call.earnings

    quick!

    row = stats.call
    assert_equal 250, row.works_total
    assert_equal 100, row.payout, "the per-order minimum applies"
    assert_equal 19, row.parts_commission, "2% of 950"
    assert_equal 1, row.completed_count
  end

  test "a one-off service with its own name and price, and no materials" do
    sign_in(@mechanic)

    quick!(works: { "0" => { service_id: "", name: "Підкачати колеса", quantity: 1, price: 50 },
                    "1" => { service_id: "", name: "", quantity: 1, price: "" } },
           parts: { "0" => { part_id: "", name: "", quantity: 1, price: "" } })

    order = Order.order(:id).last
    assert order.quick?
    assert_equal [ "Підкачати колеса" ], order.order_works.map(&:name), "an untouched row is not a line"
    assert_empty order.order_parts
    assert_equal 50, order.total
  end

  test "without a mechanic nothing is recorded and the rows come back as typed" do
    sign_in(@owner)

    assert_no_difference -> { Order.count } do
      quick!(mechanic_id: "", works: { "0" => { service_id: "", name: "Регулювання гальм", quantity: 1, price: 150 } },
             headers: stream_headers)
    end

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=update][target=modal] template", html: /Оберіть механіка/
    assert_select "turbo-stream template", html: /value="Регулювання гальм"/
  end

  test "without a single service or material nothing is recorded" do
    sign_in(@owner)

    assert_no_difference -> { Order.count } do
      quick!(works: { "0" => { service_id: "", name: "", quantity: 1, price: "" } },
             parts: { "0" => { part_id: "", name: "", quantity: 1, price: "" } }, headers: stream_headers)
    end

    assert_response :unprocessable_entity
    assert_select "turbo-stream template", html: /Додайте хоча б одну послугу або матеріал/
  end

  test "a one-off line without a price is refused by name" do
    sign_in(@owner)

    assert_no_difference -> { Order.count } do
      quick!(works: { "0" => { service_id: "", name: "Змастити ланцюг", quantity: 1, price: "" } }, headers: stream_headers)
    end

    assert_select "turbo-stream template", html: /Послуга «Змастити ланцюг»: Ціна/
  end

  test "a regular order still needs a client and a bike" do
    order = Order.new(accepted_by: @owner, accepted_at: Time.current, status: :intake)

    assert_not order.valid?
    assert order.errors.include?(:client)
    assert order.errors.include?(:bike)
  end

  # The regression that matters: every page that lists or shows closed orders
  # assumed a client and a bike.
  test "pages that show closed orders render a quick service" do
    sign_in(@owner)
    quick!
    order = Order.order(:id).last

    get orders_path(status: "archive")
    assert_response :success
    assert_select "a[href=?]", order_path(order)
    assert_match "Швидкий сервіс", response.body

    get order_path(order)
    assert_response :success
    assert_select "h1", "Швидкий сервіс"

    get mechanic_path(@mechanic)
    assert_response :success
    assert_select "a[href=?]", order_path(order), text: /Швидкий сервіс/

    get finances_path
    assert_response :success
    assert_select "a[href=?]", order_path(order)

    get search_path(q: order.number.to_s)
    assert_response :success
    assert_select "a[href=?]", order_path(order), text: /Швидкий сервіс/

    get statistics_path
    assert_response :success

    get mechanics_path
    assert_response :success
  end
end
