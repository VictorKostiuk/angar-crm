require "test_helper"

class BikesAndSearchTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @client = clients(:ivan)
    @bike = bikes(:trek)
    @other = @client.bikes.create!(name: "Cube Aim")
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  def order_for(bike, status:)
    Order.create!(client: @client, bike: bike, accepted_by: @owner, accepted_at: Time.current,
                  status: status, cancel_reason: ("передумав" if status == :cancelled))
  end

  # "У майстерні" means: has an order that is still open. A bike that has never
  # been brought in therefore reads as "Видано".
  test "the bikes list marks which are in the shop and which are back with the client" do
    order_for(@bike, status: :in_progress)
    order_for(@other, status: :closed)

    get bikes_path

    assert_response :success
    assert_select "#bike_row_#{@bike.id}", html: /У майстерні/
    assert_select "#bike_row_#{@other.id}", html: /Видано/
  end

  def query_count
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  # The badge is one grouped query for the whole list, so the query count must
  # not grow with the number of rows.
  test "the badge costs the same whether the list has three bikes or twelve" do
    3.times { |i| @client.bikes.create!(name: "Малий #{i}") }
    get bikes_path # warm the view/schema caches out of the measurement
    few = query_count { get bikes_path }

    9.times { |i| @client.bikes.create!(name: "Великий #{i}") }
    many = query_count { get bikes_path }

    assert_equal few, many, "the in-shop badge is issuing a query per row"
  end

  test "an archived bike is still reachable from history, and says so" do
    @other.update!(active: false)

    get bike_path(@other)

    assert_response :success
    assert_select "span", text: "Архівовано"
    assert_select "span", text: "Видано", count: 0
  end

  test "a bike has its own page with its details and order history" do
    order = order_for(@bike, status: :in_progress)

    get bike_path(@bike)

    assert_response :success
    assert_select "h1", text: @bike.name
    assert_select "a[href=?]", client_path(@client), text: @client.name
    assert_select "a[href=?]", order_path(order), text: "##{format('%03d', order.number)}"
    assert_select "span", text: "У майстерні"
  end

  test "the bikes list and the orders list both link to the bike page" do
    order = order_for(@bike, status: :in_progress)

    get bikes_path
    assert_select "#bike_row_#{@bike.id} a[href=?]", bike_path(@bike), text: @bike.name

    get orders_path
    assert_select "tbody a[href=?]", bike_path(@bike), text: @bike.name
    assert_select "tbody a[href=?]", client_path(@client)
    assert_equal order.bike, @bike
  end

  test "the orders search finds an order by its bike" do
    on_trek = order_for(@bike, status: :in_progress)
    on_cube = order_for(@other, status: :in_progress)

    get orders_path(q: "Cube")

    assert_select "tbody a", text: "##{format('%03d', on_cube.number)}"
    assert_select "tbody a", text: "##{format('%03d', on_trek.number)}", count: 0
  end

  test "searching by client name still works alongside bike search" do
    order = order_for(@bike, status: :in_progress)

    get orders_path(q: @client.name.split.first)
    assert_select "tbody a", text: "##{format('%03d', order.number)}"
  end

  test "the catalogs are searchable and the search survives a category click" do
    category = Category.create!(name: "Гальма", kind: :part)
    pads = Part.create!(name: "Колодки Shimano", category: category, base_price: 300)
    Part.create!(name: "Сідло Selle", category: category, base_price: 700)

    get parts_path(q: "Колодки")
    assert_select "#parts_rows", html: /#{pads.name}/
    assert_select "#parts_rows", html: /Selle/, count: 0

    # The pills must carry the query, or clicking one throws the search away.
    assert_select "a[href=?]", parts_path(category_id: category.id, q: "Колодки")

    service_category = Category.create!(name: "Ремонт", kind: :service)
    Service.create!(name: "Заміна ланцюга", category: service_category, base_price: 250)
    Service.create!(name: "Миття", category: service_category, base_price: 150)

    get services_path(q: "ланцюга")
    assert_select "#services_rows", html: /Заміна ланцюга/
    assert_select "#services_rows", html: /Миття/, count: 0
  end
end
