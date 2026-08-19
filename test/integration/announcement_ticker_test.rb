require "test_helper"

class AnnouncementTickerTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  test "the header stays clean until the owner writes something" do
    sign_in(users(:owner))
    get root_path

    assert_response :success
    assert_select ".led-ticker", 0
  end

  # This renders in shared/_shell on every page, including 404s and Turbo Stream
  # responses — it must never write.
  test "rendering the header issues no write" do
    sign_in(users(:owner))

    assert_no_difference -> { Announcement.count } do
      get root_path
      get orders_path
    end
  end

  test "the owner writes the text and it appears in the header for everyone" do
    sign_in(users(:owner))

    assert_difference -> { Announcement.count }, 1 do
      patch announcement_path, params: { announcement: { text: "У суботу до 15:00", active: "1" } }
    end
    assert_redirected_to edit_announcement_path

    # Display is universal — the sign is for the whole shop, not just the owner.
    sign_in(users(:andrii))
    get root_path
    assert_select ".led-ticker" do
      assert_select ".led-ticker__copy", 2, "the marquee needs both copies to loop seamlessly"
      assert_select ".led-ticker__copy", text: "У суботу до 15:00"
    end
    assert_select ".led-ticker[style*=?]", "--led-duration"
  end

  test "unticking Показувати hides it without losing the text" do
    Announcement.create!(text: "Сховане", active: false)

    sign_in(users(:owner))
    get root_path
    assert_select ".led-ticker", 0

    # Blank text is the other way of saying off, and must not leave a dark box.
    Announcement.first.update!(text: "", active: true)
    get root_path
    assert_select ".led-ticker", 0
  end

  test "the text is escaped in both copies" do
    Announcement.create!(text: "<script>alert(1)</script>", active: true)

    sign_in(users(:owner))
    get root_path

    assert_no_match "<script>alert(1)</script>", response.body
    assert_equal 2, response.body.scan("&lt;script&gt;alert(1)&lt;/script&gt;").size
  end

  test "scroll duration is clamped at both ends" do
    assert_equal 8, Announcement.new(text: "Коротко").scroll_duration
    assert_equal 30, Announcement.new(text: "x" * Announcement::MAX_LENGTH).scroll_duration
    assert_equal 20, Announcement.new(text: "x" * 120).scroll_duration
  end

  test "only the owner can edit it" do
    sign_in(users(:andrii))

    get edit_announcement_path
    assert_redirected_to root_path

    assert_no_difference -> { Announcement.count } do
      patch announcement_path, params: { announcement: { text: "Механік не пише сюди" } }
    end
    assert_redirected_to root_path
  end

  test "the settings screen shows what is currently in the header" do
    sign_in(users(:owner))

    get edit_announcement_path
    assert_response :success
    assert_select "p", text: "Нічого не показується."

    Announcement.create!(text: "У суботу до 15:00", active: true)
    get edit_announcement_path
    assert_select ".led-ticker .led-ticker__copy", text: "У суботу до 15:00"
    assert_select "p", text: "Нічого не показується.", count: 0
  end

  test "an over-long text is rejected" do
    sign_in(users(:owner))

    patch announcement_path, params: { announcement: { text: "x" * (Announcement::MAX_LENGTH + 1) } }

    assert_response :unprocessable_entity
    assert_equal 0, Announcement.count
  end
end
