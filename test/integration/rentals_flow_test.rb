require "test_helper"

class RentalsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii)
    @bike = RentalBike.create!(name: "Trek № 3", daily_rate: 300)
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  def issue!(from: Date.current, to: Date.current + 2, bike: @bike, **extra)
    post rentals_path, params: { rental: { rental_bike_id: bike.id, renter_name: "Гість",
                                           rented_from: from, rented_to: to }.merge(extra) },
         headers: { "Accept" => "#{Mime[:turbo_stream]}, text/html, application/xhtml+xml" }
  end

  # Nights, not inclusive days — 20.08 → 22.08 is 2 доби, as specified.
  test "the amount is the daily rate times the nights" do
    issue!(from: Date.new(2026, 8, 20), to: Date.new(2026, 8, 22))

    rental = Rental.order(:id).last
    assert_equal 2, rental.days
    assert_equal 600, rental.amount
    assert_equal 300, rental.daily_rate, "the rate is snapshotted onto the hire"
  end

  test "out and back the same day still bills one day" do
    issue!(from: Date.current, to: Date.current)

    assert_equal 1, Rental.order(:id).last.days
  end

  # Changing a bike's price must not rewrite what a past hire cost.
  test "repricing the bike leaves past hires alone" do
    issue!
    @bike.update!(daily_rate: 900)

    assert_equal 600, Rental.order(:id).last.amount
  end

  test "an explicit rate overrides the bike's" do
    issue!(daily_rate: "500")

    assert_equal 1000, Rental.order(:id).last.amount
  end

  test "the fleet shows what is available and what is out" do
    free = RentalBike.create!(name: "Cube прокат", daily_rate: 250)
    issue!

    get rentals_path
    assert_response :success
    assert_select "td", text: "Доступний"
    assert_select "td", text: "У прокаті"
    assert_select "td", text: free.display_name
  end

  test "a bike already out cannot be issued again until it comes back" do
    issue!

    assert_no_difference -> { Rental.count } do
      issue!
    end
    assert_response :unprocessable_entity

    rental = Rental.order(:id).last
    patch rental_path(rental)
    assert_not_nil rental.reload.returned_at

    assert_difference -> { Rental.count }, 1 do
      issue!
    end
  end

  test "returning does not change the money — it was earned on issue" do
    issue!
    rental = Rental.order(:id).last

    patch rental_path(rental)

    assert_equal 600, rental.reload.amount
    refute rental.out?
  end

  test "an end date before the start is rejected" do
    assert_no_difference -> { Rental.count } do
      issue!(from: Date.current, to: Date.current - 3)
    end
    assert_response :unprocessable_entity
  end

  test "rental income reaches the finances page and the net profit" do
    issue! # 600

    get finances_path(period: "month")

    assert_select "p", text: "Прокат"
    assert_select "p", text: ApplicationController.helpers.money(600)
  end

  test "only owner and admin extend the fleet, but any role can issue" do
    post session_path, params: { email_address: @mechanic.email_address, password: "password123" }

    get rentals_path
    assert_response :success
    assert_select "form[action=?]", rental_bikes_path, 0

    assert_no_difference -> { RentalBike.count } do
      post rental_bikes_path, params: { rental_bike: { name: "Свій", daily_rate: 100 } }
    end
    assert_redirected_to root_path

    assert_difference -> { Rental.count }, 1 do
      issue!
    end
  end
end
