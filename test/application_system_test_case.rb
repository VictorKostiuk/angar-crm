require "test_helper"
require "capybara/cuprite"

# Cuprite talks CDP straight to the Chrome already on the machine, so there is
# no chromedriver to install and no browser to download.
Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [ 1400, 1100 ], process_timeout: 30, timeout: 20,
                                     browser_options: { "no-sandbox": nil })
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite

  def sign_in(user, password: "password123")
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_on I18n.t("actions.sign_in")
    assert_text I18n.t("nav.workshop")
  end
end
