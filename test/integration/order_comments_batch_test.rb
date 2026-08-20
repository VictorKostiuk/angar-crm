require "test_helper"

# The remaining items from the review round.
class OrderCommentsBatchTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           accepted_at: Time.current, status: :intake)
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  test "the board card shows the order number" do
    get root_path

    assert_response :success
    assert_select "#board_card_#{@order.id}", html: /##{format('%03d', @order.number)}/
  end

  # Assigning the mechanic rides the same transaction as the status change, so
  # the two can't end up out of step.
  test "the status modal picks the mechanic who will do the job" do
    get edit_order_status_path(@order), headers: { "Turbo-Frame" => "modal" }
    assert_select "select[name=mechanic_id] option", text: @mechanic.name

    patch order_status_path(@order),
          params: { status: "in_progress", mechanic_id: @mechanic.id },
          headers: { "Accept" => "#{Mime[:turbo_stream]}, text/html" }

    @order.reload
    assert @order.in_progress?
    assert_equal @mechanic, @order.mechanic
  end

  test "a rejected status change leaves the mechanic untouched" do
    patch order_status_path(@order),
          params: { status: "closed", mechanic_id: @mechanic.id },
          headers: { "Accept" => "#{Mime[:turbo_stream]}, text/html" }

    assert_response :unprocessable_entity
    assert_nil @order.reload.mechanic_id
    assert @order.intake?
  end

  test "cancelled orders leave the live list and land in the archive" do
    cancelled = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                              accepted_at: Time.current, status: :cancelled, cancel_reason: "передумав")

    get orders_path
    assert_select "tbody a", text: "##{format('%03d', cancelled.number)}", count: 0
    assert_select "tbody a", text: "##{format('%03d', @order.number)}"

    get orders_path(status: "archive")
    assert_select "tbody a", text: "##{format('%03d', cancelled.number)}"
    assert_select "tbody a", text: "##{format('%03d', @order.number)}", count: 0

    get root_path
    assert_select "a[href=?]", orders_path(status: "archive"), text: "Архів"
  end

  test "photos open full size instead of only rendering a thumbnail" do
    @order.photos.attach(io: File.open(Rails.root.join("test/fixtures/files/test_photo.png")),
                         filename: "test_photo.png", content_type: "image/png")

    get order_path(@order)

    assert_select "[data-controller=lightbox]" do
      assert_select "img[data-action=?][data-full-src]", "click->lightbox#open"
      assert_select "dialog[data-lightbox-target=dialog] img[data-lightbox-target=image]"
    end
  end

  # `link_to :back` renders href="javascript:history.back()" — it hands the
  # app's navigation to the browser's history and can land anywhere.
  test "back links point at real routes" do
    get order_path(@order)
    assert_select "a[href=?]", orders_path, text: "← До замовлень"
    assert_select "a[href^=javascript]", 0

    get new_order_path
    assert_select "a[href=?]", orders_path, text: "← До замовлень"
    assert_select "a[href^=javascript]", 0
  end

  test "clicking a bike on the client card filters the order history" do
    other = @order.client.bikes.create!(name: "Cube Aim")
    on_other = Order.create!(client: clients(:ivan), bike: other, accepted_by: @owner,
                             accepted_at: Time.current, status: :intake)

    get client_path(@order.client)
    assert_select "tbody a", text: "##{format('%03d', @order.number)}"
    assert_select "tbody a", text: "##{format('%03d', on_other.number)}"

    get client_path(@order.client, bike_id: other.id)
    assert_select "a.bg-brand-600", text: other.display_name
    assert_select "tbody a", text: "##{format('%03d', on_other.number)}"
    assert_select "tbody a", text: "##{format('%03d', @order.number)}", count: 0
  end

  test "the sidebar is pinned to the viewport instead of scrolling with content" do
    get root_path

    assert_select "aside.lg\\:sticky.lg\\:h-screen"
  end
end
