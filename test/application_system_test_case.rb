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

  setup do
    # Cuprite reuses its browser. A preceding responsive test may leave it at
    # phone width; subclasses can apply their own viewport after this reset.
    page.driver.resize_window(1400, 1100)
    Timeout.timeout(5) { sleep 0.05 until page.evaluate_script("window.innerWidth") == 1400 }
  end

  def sign_in(user, password: "password123")
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_on I18n.t("actions.sign_in")
    # Wait on the signed-in shell itself, not on a word that also exists on the
    # sign-in page's chrome — the assertion has to prove the session took.
    assert_selector "aside", text: user.name, wait: 10
  end

  # Picks an option in a searchable select (D66): the <select> itself is
  # hidden, so open the picker next to it, optionally type, and click.
  def pick(text, from:, search: nil)
    select = find(from, visible: :all)
    picker = select.find(:xpath, "following-sibling::*[@data-combobox-ui][1]")
    # A multiple picker stays open between picks; a click would close it.
    picker.find("[role=combobox]").click unless picker.has_css?("[role=listbox]", wait: 0)
    picker.find("input[type=search]").set(search) if search
    picker.find("[role=option]", text: text, match: :prefer_exact).click
  end
end
