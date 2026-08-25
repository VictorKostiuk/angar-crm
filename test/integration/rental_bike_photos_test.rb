require "test_helper"

class RentalBikePhotosTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii)
    @bike = RentalBike.create!(name: "Trek прокат", daily_rate: 300)
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  def photo(name = "test_photo.png")
    fixture_file_upload(name, "image/png")
  end

  test "several photos can be attached to a rental bike" do
    assert_difference -> { @bike.photos.count }, 2 do
      patch rental_bike_path(@bike), params: { rental_bike: { photos: [ photo, photo ] } }
    end

    assert_redirected_to rentals_path
    get rentals_path
    assert_select "[data-controller=lightbox] img[data-action=?]", "click->lightbox#open", 2
  end

  test "photos can be attached while creating the bike" do
    assert_difference -> { RentalBike.count }, 1 do
      post rental_bikes_path, params: { rental_bike: { name: "Cube прокат", daily_rate: 250, photos: [ photo ] } }
    end

    assert_equal 1, RentalBike.order(:id).last.photos.count
  end

  test "a photo can be removed one at a time" do
    patch rental_bike_path(@bike), params: { rental_bike: { photos: [ photo, photo ] } }
    target = @bike.reload.photos.first

    assert_difference -> { @bike.reload.photos.count }, -1 do
      delete photo_rental_bike_path(@bike, photo_id: target.id)
    end
    assert_redirected_to rentals_path
  end

  test "attaching a photo leaves the rest of the record alone" do
    patch rental_bike_path(@bike), params: { rental_bike: { photos: [ photo ] } }

    @bike.reload
    assert_equal "Trek прокат", @bike.name
    assert_equal 300, @bike.daily_rate
  end

  test "a non-image is refused" do
    assert_no_difference -> { @bike.photos.count } do
      patch rental_bike_path(@bike), params: {
        rental_bike: { photos: [ fixture_file_upload("not_an_image.txt", "text/plain") ] }
      }
    end
    assert_redirected_to rentals_path
  end

  # Managing the fleet is owner/admin; a mechanic issues bikes but doesn't
  # curate the documents.
  test "a mechanic sees the photos but cannot add or remove them" do
    patch rental_bike_path(@bike), params: { rental_bike: { photos: [ photo ] } }
    target = @bike.reload.photos.first

    post session_path, params: { email_address: @mechanic.email_address, password: "password123" }

    get rentals_path
    assert_select "img[data-action=?]", "click->lightbox#open", 1
    assert_select "input[type=file]", 0

    assert_no_difference -> { @bike.reload.photos.count } do
      delete photo_rental_bike_path(@bike, photo_id: target.id)
    end
    assert_redirected_to root_path
  end
end
