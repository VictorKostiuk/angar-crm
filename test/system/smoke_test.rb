require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  test "signing in reaches the board" do
    sign_in users(:owner)

    assert_selector "aside nav a", text: I18n.t("nav.orders")
  end
end
