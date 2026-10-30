require "test_helper"

# D69: the header box finds a bike by its name — including one whose visits
# are all closed, which the old box (the orders list, archive hidden) missed —
# plus clients and an order typed by its number.
class GlobalSearchTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
    @bike = bikes(:trek)
  end

  def frame_headers
    { "Turbo-Frame" => "global_search_results" }
  end

  test "a bike whose orders are all closed is found by its name" do
    order = Order.create!(client: @bike.client, bike: @bike, accepted_by: @owner, accepted_at: 1.month.ago, status: :intake)
    order.update_columns(status: Order.statuses[:closed])

    get search_path(q: "marlin")

    assert_response :success
    assert_select "a[href=?]", bike_path(@bike), text: /#{Regexp.escape(@bike.display_name)}/
    assert_match @bike.client.name, response.body
  end

  test "every word counts, in any order" do
    get search_path(q: "marlin trek")
    assert_select "a[href=?]", bike_path(@bike)

    get search_path(q: "marlin cube")
    assert_select "a[href=?]", bike_path(@bike), 0
    assert_match "Нічого не знайдено", response.body
  end

  test "typing fills the dropdown frame with a few results and a link to all" do
    get search_path(q: "trek"), headers: frame_headers

    assert_select "turbo-frame#global_search_results[target=_top] a[href=?]", bike_path(@bike)
    assert_select "a[href=?]", search_path(q: "trek"), text: "Усі результати →"
    assert_no_match "<aside", response.body, "only the frame, no page around it"
  end

  test "an order number and a client's phone are found too" do
    order = Order.create!(client: @bike.client, bike: @bike, accepted_by: @owner, accepted_at: Time.current, status: :intake)

    get search_path(q: "##{order.number}")
    assert_select "a[href=?]", order_path(order)

    get search_path(q: @bike.client.phone.last(7))
    assert_select "a[href=?]", client_path(@bike.client)
  end

  test "the header box opens the search page and keeps the query only there" do
    get orders_path(q: "trek")
    assert_select "header form[action=?] input[name=q]:not([value])", search_path

    get search_path(q: "trek")
    assert_select "header input[name=q][value=?]", "trek"
  end
end
