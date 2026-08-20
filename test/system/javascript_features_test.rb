require "application_system_test_case"

class JavascriptFeaturesSystemTest < ApplicationSystemTestCase
  setup do
    @owner = users(:owner)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           accepted_at: Time.current, status: :in_progress)
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
