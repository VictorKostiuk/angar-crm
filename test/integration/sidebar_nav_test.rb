require "test_helper"

class SidebarNavTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  # shared/_icon renders nothing for a name its case statement doesn't know, so
  # a typo'd or missing icon: would silently leave a label with no glyph.
  def assert_every_nav_entry_has_an_icon(expected_count)
    assert_select "nav > a, nav > span" do |entries|
      assert_equal expected_count, entries.size
      entries.each do |entry|
        assert_equal 1, entry.css("svg").size, "«#{entry.text.strip}» renders no icon"
      end
    end
  end

  test "the catalogs are named Послуги and Запчастини" do
    sign_in(users(:owner))
    get root_path

    assert_select "nav a", text: "Послуги"
    assert_select "nav a", text: "Запчастини"
    assert_select "nav a", text: "Роботи", count: 0
    assert_select "nav a", text: "Деталі / матеріали", count: 0
  end

  test "every sidebar entry the owner sees carries an icon" do
    sign_in(users(:owner))
    get root_path

    assert_response :success
    assert_every_nav_entry_has_an_icon 11
    assert_select "nav > span", 0, "the owner has no disabled entries"
  end

  test "the entries a mechanic cannot open are still rendered with their icon" do
    sign_in(users(:andrii))
    get root_path

    assert_response :success
    assert_every_nav_entry_has_an_icon 11
    assert_select "nav > span", 5, "services, parts, suppliers, finances and settings are gated"
  end
end
