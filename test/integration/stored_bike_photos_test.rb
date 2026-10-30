require "test_helper"

# D68: a bike that is already in the base has been photographed — at an
# earlier visit or on its own page — so a new order shows those photos
# instead of an empty box, and nobody re-shoots the same bike every visit.
class StoredBikePhotosTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @bike = bikes(:trek)
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  def photo
    fixture_file_upload("test_photo.png", "image/png")
  end

  def order!(**attributes)
    Order.create!(client: @bike.client, bike: @bike, accepted_by: @owner, accepted_at: Time.current,
                  status: :intake, **attributes)
  end

  test "an order with no photos shows the bike's photos from the base, marked as such" do
    @bike.photos.attach(photo)
    earlier = order!(accepted_at: 1.month.ago, status: :closed)
    earlier.photos.attach(photo)
    order = order!

    get order_path(order)

    assert_match "З бази — фото цього велосипеда", response.body
    assert_select "img.border-dashed", 2
  end

  test "an order's own photos are shown instead of the stored ones" do
    @bike.photos.attach(photo)
    order = order!
    order.photos.attach(photo)

    get order_path(order)

    assert_no_match "З бази", response.body
  end

  test "the board card falls back to the bike's photo" do
    @bike.photos.attach(photo)
    order!

    get root_path

    assert_select "#board_card_#{Order.last.id} img", 1
  end

  test "picking a bike at intake shows its photo from the base" do
    @bike.photos.attach(photo)

    get new_order_path(client_id: @bike.client_id)

    assert_select "label:has(input[name=bike_id][value=?]) img", @bike.id.to_s, 1
  end
end
