require "application_system_test_case"

class JavascriptFeaturesSystemTest < ApplicationSystemTestCase
  setup do
    @owner = users(:owner)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           mechanic: users(:andrii), accepted_at: Time.current, status: :in_progress)
  end

  # Was a nested <form> inside the order form; the parser dropped it whole, so
  # typing did nothing at all.
  test "the client search on the intake screen returns results and picks one" do
    sign_in @owner
    visit new_order_path

    fill_in "client_search", with: clients(:ivan).name.split.first
    assert_text clients(:ivan).formatted_phone   # results loaded into the frame

    click_on clients(:ivan).name
    assert_text "Змінити"                        # both sections re-rendered
    assert_selector "input[name='client_id']", visible: :all
  end

  test "the catalog modal filters by category and by search together" do
    brakes = Category.create!(name: "Гальма", kind: :part)
    drive = Category.create!(name: "Трансмісія", kind: :part)
    Part.create!(name: "Колодки Shimano", category: brakes, base_price: 300)
    Part.create!(name: "Ланцюг Shimano", category: drive, base_price: 900)

    sign_in @owner
    visit order_path(@order)
    click_on "+ Додати запчастину"

    assert_text "Колодки Shimano"
    assert_text "Ланцюг Shimano"

    click_on "Гальма"
    assert_text "Колодки Shimano"
    assert_no_text "Ланцюг Shimano"

    # Typing must keep the selected category, not reset it.
    fill_in "Пошук запчастини", with: "Shimano"
    assert_text "Колодки Shimano"
    assert_no_text "Ланцюг Shimano"
  end

  test "clicking a photo opens it full size" do
    @order.photos.attach(io: File.open(Rails.root.join("test/fixtures/files/test_photo.png")),
                         filename: "test_photo.png", content_type: "image/png")
    sign_in @owner
    visit order_path(@order)

    assert_no_selector "dialog[open]"
    find("img[data-action='click->lightbox#open']").click
    assert_selector "dialog[open] img[data-lightbox-target='image']"
  end

  # Proves the whole wiring the copy feature rides on: the header link loads the
  # #modal frame, the dialog opens itself, and the message lands in the textarea
  # the mechanic selects from. The copy button is deliberately not clicked here —
  # headless Chrome's clipboard permissions are flaky, and the readable textarea
  # is what carries the feature when the Clipboard API is unavailable anyway.
  test "the ready-for-pickup message opens with the works and the total in it" do
    @order.order_works.create!(name: "Заміна ланцюга", quantity: 1, price: 500)
    @order.update!(status: :waiting_pickup)

    sign_in @owner
    visit order_path(@order)
    find("a[aria-label='Повідомлення клієнту']").click

    assert_selector "dialog[open]", text: "Повідомлення клієнту"
    message = find("textarea[data-clipboard-target='source']").value
    assert_includes message, "Добрий день, #{clients(:ivan).name.split.first}!"
    assert_includes message, "- Заміна ланцюга — 500 грн"
    assert_includes message, "До сплати: 500 грн"
  end

  test "the sale form adds another line" do
    part = Part.create!(name: "Камера", category: Category.part.active.first, base_price: 180)
    StockMovement.create!(part: part, kind: :receipt, quantity: 5, user: @owner)

    sign_in @owner
    visit root_path
    click_on "+ Новий продаж"

    assert_selector "select[name*='part_id']", count: 1
    click_on "+ Ще позиція"
    assert_selector "select[name*='part_id']", count: 2
  end

  # Type-to-narrow over the parts list. Asserted through the <select>'s own
  # options rather than by clicking: the point of the design is that the native
  # control survives filtering, so that is the thing worth checking.
  test "the sale form's part list narrows as you type" do
    category = Category.part.active.first
    Part.create!(name: "Колодки Shimano B01S", category: category, base_price: 350)
    Part.create!(name: "Каретка Shimano BB-RS500", category: category, base_price: 650)
    Part.create!(name: "Камера 700x35/43", category: category, base_price: 180)

    sign_in @owner
    visit root_path
    click_on "+ Новий продаж"

    # +1 for «Своя позиція» — counted off the catalogue rather than hardcoded,
    # since the parts fixture contributes rows of its own.
    all_options = Part.active.count + 1
    assert_selector "select[name*='part_id'] option", count: all_options

    fill_in "Пошук позиції…", with: "shimano"
    assert_selector "select[name*='part_id'] option", count: 3
    assert_no_selector "select[name*='part_id'] option", text: "Камера 700x35/43"
    # The blank row is never filtered away — it is how a one-off line is chosen.
    assert_selector "select[name*='part_id'] option", text: "Своя позиція (не зі складу)"

    # Real backspace keys, not `fill_in with: ""`: Cuprite clears by assignment
    # there and fires no input event, so the filter never hears about it —
    # verified against the browser, not assumed.
    find("input[placeholder='Пошук позиції…']").send_keys(*Array.new(8) { :backspace })
    assert_selector "select[name*='part_id'] option", count: all_options
  end

  # Reported: "every time i type 1 letter page refreshes and field focus removes".
  # The search box sat inside the frame its own debounced submit replaced, so the
  # input was destroyed and rebuilt on every keystroke. Asserting focus and the
  # full typed value is the whole point — narrowing alone passed before the fix.
  test "typing in the parts search keeps focus and everything typed" do
    category = Category.part.active.first
    Part.create!(name: "Колодки Shimano B01S", category: category, base_price: 350)
    Part.create!(name: "Камера 700x35/43", category: category, base_price: 180)

    sign_in @owner
    visit parts_path

    field = find("input[placeholder='Пошук за назвою запчастини…']")
    field.click
    field.send_keys("s", "h", "i", "m")

    assert_selector "#parts_rows td", text: "Колодки Shimano B01S"
    assert_no_selector "#parts_rows td", text: "Камера 700x35/43"

    assert_equal "q", page.evaluate_script("document.activeElement.name"),
      "the search box must still hold focus after the results swap"
    assert_equal "shim", page.evaluate_script("document.activeElement.value"),
      "characters typed while the request was in flight must not be reverted"

    # The filtered view still survives a reload and can still be shared (D45's
    # reason for data-turbo-action="advance" on the frame).
    assert_match(/q=shim/, page.current_url)
  end

  test "a filter swaps only its own frame and keeps the page in place" do
    sign_in @owner
    visit parts_path

    assert_selector "turbo-frame#parts_list"
    within("turbo-frame#parts_list") { fill_in "q", with: "нічого-такого-немає" }
    assert_text "Немає"
    # The page around the frame is untouched — the sidebar never re-rendered.
    assert_selector "aside nav a", text: I18n.t("nav.orders")
  end

  test "the sidebar stays put while the content scrolls" do
    12.times { |i| Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                                 accepted_at: Time.current, status: :in_progress) }
    sign_in @owner
    visit orders_path

    top_before = page.evaluate_script("document.querySelector('aside').getBoundingClientRect().top")
    page.execute_script("document.querySelector('main').scrollTop = 600")
    sleep 0.2
    top_after = page.evaluate_script("document.querySelector('aside').getBoundingClientRect().top")

    assert_equal top_before, top_after, "the sidebar must not scroll away with the content"
    assert_selector "aside", text: @owner.name, visible: true
  end
end
