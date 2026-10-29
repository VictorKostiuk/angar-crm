require "test_helper"

class Bookings::DayTest < ActiveSupport::TestCase
  MONDAY = Date.new(2026, 11, 2)

  setup do
    travel_to Time.zone.local(2026, 11, 1, 12, 0) # the Sunday before
    @hours = WorkingHour.create!(weekday: 1, opens_at: "10:00", closes_at: "13:00", slot_minutes: 30, capacity: 1)
  end

  def book!(time, minutes: 60, status: :booked)
    order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: users(:owner), accepted_at: Time.current,
                          status: :booked, scheduled_at: Time.zone.parse("#{MONDAY} #{time}"), booking_minutes: minutes)
    order.update_columns(status: Order.statuses[status]) unless status == :booked
    order
  end

  def starts(date = MONDAY, minutes = 60)
    Bookings::Day.new(date).free_starts(minutes).map { |t| t.strftime("%H:%M") }
  end

  test "an empty day offers every step that fits before closing" do
    assert_equal %w[ 10:00 10:30 11:00 11:30 12:00 ], starts
  end

  test "a booking that would run past closing is not offered" do
    assert_equal %w[ 10:00 10:30 11:00 ], starts(MONDAY, 120)
  end

  test "a booking blocks every start that would overlap it at capacity 1" do
    book!("11:00")

    assert_equal %w[ 10:00 12:00 ], starts
  end

  test "with two places, a slot closes only when both are taken" do
    @hours.update!(capacity: 2)
    book!("11:00")
    assert_equal %w[ 10:00 10:30 11:00 11:30 12:00 ], starts

    book!("11:00")
    assert_equal %w[ 10:00 12:00 ], starts
  end

  # Overlap peaks where a booking starts, not only on the grid — a booking at
  # 10:45 (made under an older 15-minute step) must still block 10:30.
  test "an off-grid booking still blocks the slots it overlaps" do
    book!("10:45")

    assert_equal %w[ 12:00 ], starts
  end

  test "a cancelled booking frees its slot; an arrived one keeps holding it" do
    book!("10:00", status: :cancelled)
    book!("12:00", status: :in_progress)

    assert_equal %w[ 10:00 10:30 11:00 ], starts
  end

  test "a day with no hours row, or marked closed, takes no bookings" do
    assert_not Bookings::Day.new(MONDAY + 1).open?, "Tuesday has no row"

    @hours.update!(closed: true)
    assert_equal [], starts
  end

  test "a shortened day uses its own hours and capacity" do
    ScheduleException.create!(date: MONDAY, closes_at: "11:00")

    day = Bookings::Day.new(MONDAY)
    assert day.shortened?
    assert_equal %w[ 10:00 ], starts
  end

  test "a special day with its own hours opens a normal day off" do
    tuesday = MONDAY + 1 # no hours row
    ScheduleException.create!(date: tuesday, opens_at: "10:00", closes_at: "11:00")

    assert_equal %w[ 10:00 ], starts(tuesday)
  end

  test "a holiday closes the day outright" do
    ScheduleException.create!(date: MONDAY, closed: true, note: "Свято")

    assert_equal [], starts
  end

  test "times already past today are not offered" do
    travel_to Time.zone.parse("#{MONDAY} 10:40")

    assert_equal %w[ 11:00 11:30 12:00 ], starts
  end

  test "a booking outside shortened hours is flagged, not dropped" do
    book!("12:00")
    ScheduleException.create!(date: MONDAY, closes_at: "11:00")

    day = Bookings::Day.new(MONDAY)
    booking = day.bookings.sole
    assert day.out_of_hours?(booking)
  end

  # Kyiv leaves summer time on 25.10.2026. Minutes-since-midnight must land on
  # the same wall-clock time on both sides of it.
  test "slots keep their wall-clock time across the DST switch" do
    WorkingHour.create!(weekday: 6, opens_at: "10:00", closes_at: "13:00")
    travel_to Time.zone.local(2026, 10, 20, 8, 0)

    summer = Bookings::Day.new(Date.new(2026, 10, 24)).free_starts(60).first # Saturday, UTC+3
    winter = Bookings::Day.new(Date.new(2026, 10, 26)).free_starts(60).first # Monday, UTC+2
    assert_equal [ "10:00", "10:00" ], [ summer, winter ].map { |t| t.strftime("%H:%M") }
    assert_equal 3, summer.utc_offset / 3600
    assert_equal 2, winter.utc_offset / 3600
  end
end
