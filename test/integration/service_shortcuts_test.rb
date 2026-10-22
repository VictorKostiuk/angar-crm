require "test_helper"

# Shop-floor shortcuts from the 22.10.2026 feedback round: call / Telegram
# links by the client's phone, the approval message, editing the problem after
# intake, picking the seller on a sale, and the rentals tab showing who to call.
class ServiceShortcutsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           mechanic: @mechanic, accepted_at: Time.current, status: :waiting_approval,
                           problem: "Скрипить")
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  test "the order header links the client's phone to a call and a Telegram chat" do
    get order_path(@order)

    phone = clients(:ivan).phone
    assert_select "a[href=?]", "tel:+#{phone}"
    assert_select "a[href=?]", "https://t.me/+#{phone}"
  end

  test "at «Очікує погодження» the order offers a message listing the recommended works" do
    @order.order_works.create!(name: "Заміна гальм", quantity: 1, price: 400)
    @order.order_parts.create!(name: "Гальмівні колодки", quantity: 2, price: 300)

    get order_path(@order)
    assert_select "a[href=?]", order_approval_message_path(@order)

    get order_approval_message_path(@order)
    body = CGI.unescapeHTML(response.body[%r{<textarea[^>]*>(.*?)</textarea>}m, 1])
    assert_equal <<~TEXT.strip, body
      Добрий день, Іван!

      Ми оглянули ваш велосипед «#{@order.bike.name}».

      Рекомендовані роботи:
      - Заміна гальм — 400 грн

      Потрібні запчастини:
      - Гальмівні колодки × 2 — 600 грн

      Орієнтовна вартість: 1 000 грн

      Підтвердіть, будь ласка, чи погоджуєте ці роботи — після цього беремося до справи.
    TEXT
  end

  test "the approval button is not offered once the order has moved on" do
    @order.update!(status: :in_progress)

    get order_path(@order)
    assert_select "a[href=?]", order_approval_message_path(@order), count: 0
  end

  test "the problem can be rewritten while the order is open" do
    patch order_path(@order), params: { order: { problem: "Тріснута рама" } }

    assert_equal "Тріснута рама", @order.reload.problem
  end

  test "a closed order's problem stays frozen" do
    @order.update_columns(status: Order.statuses[:closed], closed_at: Time.current)

    patch order_path(@order), params: { order: { problem: "Інше" } }
    assert_equal "Скрипить", @order.reload.problem
  end

  test "the sale is credited to the seller picked on the form, not whoever is logged in" do
    post sales_path, params: { sale: { sold_by_id: @mechanic.id,
                                       sale_items_attributes: { "0" => { name: "Фара", quantity: 1, price: 500 } } } }

    assert_equal @mechanic, Sale.order(:id).last.sold_by
  end

  test "the seller defaults to the current user" do
    get new_sale_path
    assert_select "select[name=?] option[selected][value=?]", "sale[sold_by_id]", @owner.id.to_s

    post sales_path, params: { sale: { sale_items_attributes: { "0" => { name: "Фара", quantity: 1, price: 500 } } } }
    assert_equal @owner, Sale.order(:id).last.sold_by
  end

  test "the rentals tab shows the renter's phone with call / Telegram links and their documents" do
    bike = RentalBike.create!(name: "Trek прокат", daily_rate: 300)
    rental = Rental.create!(rental_bike: bike, renter_name: "Гість", renter_phone: "097 123 45 67",
                            rented_from: Date.current, rented_to: Date.current + 1, issued_by: @owner)
    rental.documents.attach(fixture_file_upload("test_photo.png", "image/png"))

    get rentals_path

    assert_select "td[data-label=?] a[href=?]", "У кого", "tel:+380971234567"
    assert_select "td[data-label=?] a[href=?]", "Хто взяв", "https://t.me/+380971234567"
    assert_select "td[data-label=?] img[data-action=?]", "У кого", "click->lightbox#open"
  end

  test "a phone that is not a full number is printed as typed, with no links to dial" do
    bike = RentalBike.create!(name: "Trek прокат", daily_rate: 300)
    Rental.create!(rental_bike: bike, renter_name: "Гість", renter_phone: "97 123 45 67",
                   rented_from: Date.current, rented_to: Date.current + 1, issued_by: @owner)

    get rentals_path

    assert_select "td[data-label=?]", "У кого", text: /97 123 45 67/
    assert_select "a[href^=?]", "tel:", count: 0
  end

  test "a client's bike takes its own photos and shows one on the list" do
    bike = bikes(:trek)

    post bike_photos_path(bike), params: { photos: [ fixture_file_upload("test_photo.png", "image/png") ] }
    assert_redirected_to bike_path(bike)
    assert_equal 1, bike.reload.photos.count

    get bikes_path
    assert_select "#bike_row_#{bike.id} img"
  end

  test "a bike with no photo of its own falls back to its intake photos" do
    @order.photos.attach(fixture_file_upload("test_photo.png", "image/png"))

    assert_equal @order.photos.first, bikes(:trek).reload.cover_photo
  end

  test "a non-image is refused" do
    post bike_photos_path(bikes(:trek)), params: { photos: [ fixture_file_upload("not_an_image.txt", "text/plain") ] }

    assert_equal 0, bikes(:trek).reload.photos.count
  end
end
