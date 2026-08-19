require "test_helper"

class OrderIntakeFlowTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @client = clients(:ivan)
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  # The client search used to be a <form> nested inside the order form. The HTML
  # parser drops a nested <form> start tag along with every attribute on it, so
  # data-controller="debounce" never reached the DOM and typing did nothing.
  test "the intake screen never nests a form inside the order form" do
    get new_order_path

    assert_response :success
    assert_select "form form", 0, "a nested <form> is dropped by the parser — the search would silently do nothing"
  end

  # The dropped inner form left its input as part of the order form, colliding
  # with the shell's own #q search field and POSTing the query with the order.
  test "the client search input is not a submitted field of the order form" do
    get new_order_path

    assert_select "#client_search[name]", 0, "the search input must not be POSTed with the order"
    # The shell's header search legitimately GETs q to /orders; the intake form
    # (the POST one) must not carry a q field, and #q must stay unique.
    assert_select "form[method=post] [name=q]", 0
    assert_select "#q", 1
    assert_select "#client_search[data-action=?]", "input->frame-search#search"
    assert_select "[data-frame-search-frame-value=?]", "client_search_results"
  end

  # A frame navigation whose response has no matching frame fails with
  # "Content missing" — the results template had no wrapper at all.
  test "client search responds inside the frame it is loaded into" do
    get search_clients_path(q: @client.name), headers: { "Turbo-Frame" => "client_search_results" }

    assert_response :success
    assert_select "turbo-frame#client_search_results" do
      assert_select "a[href=?]", new_order_path(client_id: @client.id)
      assert_select "a[data-turbo-frame=?]", "client_and_bike"
    end

    get search_clients_path(q: "цього клієнта точно немає"), headers: { "Turbo-Frame" => "client_search_results" }
    assert_select "turbo-frame#client_search_results", html: /Клієнта не знайдено/
  end

  test "picking a client re-renders both sections inside the shared frame" do
    get new_order_path(client_id: @client.id), headers: { "Turbo-Frame" => "client_and_bike" }

    assert_response :success
    assert_select "turbo-frame#client_and_bike" do
      assert_select "input[type=hidden][name=client_id][value=?]", @client.id.to_s
      assert_select "h2", text: "1. Клієнт"
      assert_select "h2", text: "2. Велосипед"
    end
    assert_select "#client_search", 0, "the search input is replaced once a client is chosen"
  end

  test "each of the six intake sections gets its own card" do
    get new_order_path

    assert_select "form .bg-white.border.rounded-xl", 6
    (1..6).each { |n| assert_select "h2", text: /\A#{n}\. / }
  end

  test "intake still creates the order end to end" do
    assert_difference -> { Order.count }, 1 do
      post orders_path, params: { client_id: @client.id, bike_name: "Cube Aim", problem: "скрипить" }
    end

    order = Order.order(:id).last
    assert_equal @client, order.client
    assert_equal "Cube Aim", order.bike.name
    assert_redirected_to order
  end
end
