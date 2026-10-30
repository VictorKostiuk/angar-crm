require "test_helper"

class BookingSettingsTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  def week_params(overrides = {})
    WorkingHour::WEEK.each_with_index.to_h do |wday, index|
      [ index.to_s, { weekday: wday, closed: wday.zero? ? "1" : "0", opens_at: "10:00", closes_at: "19:00",
                      slot_minutes: 30, capacity: 2 }.merge(overrides.fetch(wday, {})) ]
    end
  end

  test "the settings page shows the full week even with nothing saved" do
    sign_in users(:owner)

    get booking_settings_path
    assert_response :success
    assert_select "input[name$='[weekday]']", 7
  end

  test "an unsaved week is called out on the calendar and in settings" do
    sign_in users(:owner)

    get bookings_path
    assert_match "Робочий тиждень ще не збережено", response.body
    get booking_settings_path
    assert_match "Розклад нижче ще не збережено", response.body

    WorkingHour.week.each(&:save!)
    get bookings_path
    assert_no_match "Робочий тиждень ще не збережено", response.body
  end

  test "the week is saved in one go" do
    sign_in users(:owner)

    patch working_hours_path, params: { working_hours: week_params(6 => { closes_at: "15:00", capacity: 1 }) }

    assert_redirected_to booking_settings_path
    assert_equal 7, WorkingHour.count
    saturday = WorkingHour.find_by(weekday: 6)
    assert_equal [ "15:00", 1 ], [ saturday.closes_at, saturday.capacity ]
    assert WorkingHour.find_by(weekday: 0).closed?
  end

  test "a day closing before it opens saves nothing" do
    sign_in users(:owner)

    patch working_hours_path, params: { working_hours: week_params(1 => { closes_at: "09:00" }) }

    assert_equal 0, WorkingHour.count
    assert_match "Понеділок", flash[:alert]
  end

  test "types of ТО are added, retimed and archived" do
    sign_in users(:owner)

    post maintenance_types_path, params: { maintenance_type: { name: "Повне ТО", duration_minutes: 120 } }
    type = MaintenanceType.find_by!(name: "Повне ТО")

    patch maintenance_type_path(type), params: { maintenance_type: { name: "Повне ТО", duration_minutes: 90 } }
    assert_equal 90, type.reload.duration_minutes

    delete maintenance_type_path(type)
    assert_not type.reload.active?
  end

  test "a shortened day is added and removed" do
    sign_in users(:owner)

    post schedule_exceptions_path, params: { schedule_exception: { date: "2026-12-31", opens_at: "10:00", closes_at: "14:00", note: "Передсвятковий" } }
    exception = ScheduleException.find_by!(date: Date.new(2026, 12, 31))
    assert_equal 840, exception.closes_minute

    delete schedule_exception_path(exception)
    assert_not ScheduleException.exists?(exception.id)
  end

  test "a mechanic cannot change the schedule" do
    sign_in users(:andrii)

    patch working_hours_path, params: { working_hours: week_params }
    assert_equal 0, WorkingHour.count

    post booking_problems_path, params: { booking_problem: { name: "Гальма" } }
    assert_equal 0, BookingProblem.count
  end

  # D63: the bot's quick picks, kept with the rest of the booking settings.
  test "quick-pick problems are added at the end, renamed and deleted" do
    BookingProblem.create!(name: "Гальма", position: 1)
    sign_in users(:owner)

    post booking_problems_path, params: { booking_problem: { name: "  Вісімка   на колесі " } }
    assert_redirected_to booking_settings_path
    added = BookingProblem.ordered.last
    assert_equal [ "Вісімка на колесі", 2 ], [ added.name, added.position ]

    get booking_settings_path
    assert_select "input[value='Вісімка на колесі']"

    patch booking_problem_path(added), params: { booking_problem: { name: "Вісімка" } }
    assert_equal "Вісімка", added.reload.name

    delete booking_problem_path(added)
    assert_equal [ "Гальма" ], BookingProblem.ordered.pluck(:name)
  end

  test "a problem too long for a Telegram button is refused" do
    sign_in users(:owner)

    post booking_problems_path, params: { booking_problem: { name: "а" * (BookingProblem::NAME_LIMIT + 1) } }
    assert_equal 0, BookingProblem.count
    assert flash[:alert].present?
  end
end
