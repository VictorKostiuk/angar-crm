require "test_helper"

# Every filter used to swap the whole <body> — a Turbo Drive visit, not a
# browser reload, but it reset scroll and re-rendered the page around the list.
# Each filtered region now lives in its own frame that only its own controls
# navigate.
class FilterFramesTest < ActionDispatch::IntegrationTest
  PAGES = {
    "orders_list"        => :orders_path,
    "clients_list"       => :clients_path,
    "bikes_list"         => :bikes_path,
    "parts_list"         => :parts_path,
    "services_list"      => :services_path,
    "finances_content"   => :finances_path,
    "statistics_content" => :statistics_path,
    "reports_content"    => :reports_path,
    "mechanics_content"  => :mechanics_path
  }.freeze

  setup do
    post session_path, params: { email_address: users(:owner).email_address, password: "password123" }
  end

  test "each filtered page wraps its region in a frame that lets other links out" do
    PAGES.each do |frame, path|
      get send(path)

      assert_response :success, path
      assert_select "turbo-frame##{frame}[target=_top][data-turbo-action=advance]", 1,
        "#{path} must scope its filters to a frame that other links can escape"
    end
  end

  # A frame-id typo fails silently in the browser as "Content missing" — this is
  # the assertion that catches it server-side.
  test "a filtered request returns the frame it was asked for" do
    PAGES.each do |frame, path|
      get send(path), headers: { "Turbo-Frame" => frame }

      assert_response :success, path
      assert_select "turbo-frame##{frame}", 1, "#{path} lost its frame on a frame request"
    end
  end

  test "the controls opt into their frame and the page links stay out of it" do
    get orders_path
    assert_select "form[data-turbo-frame=orders_list]"
    assert_select "a[data-turbo-frame=orders_list]", text: "Скинути фільтри"

    get clients_path
    assert_select "form[data-turbo-frame=clients_list][data-controller=debounce]"
    # Row links must NOT carry the frame — they rely on the frame's _top target.
    assert_select "tbody a[data-turbo-frame=clients_list]", 0

    get parts_path
    assert_select "a[data-turbo-frame=parts_list]", text: "Усі"
    assert_select "a[data-turbo-frame=modal]", text: "+ категорія"

    get finances_path
    assert_select "a[data-turbo-frame=finances_content]", text: "Місяць"
    assert_select "form[data-turbo-frame=finances_content]"
  end

  # A frame with nothing pointed at it is inert — the page looks framed and
  # behaves exactly as before.
  test "every frame has at least one control bound to it" do
    PAGES.each do |frame, path|
      get send(path)

      assert_select "[data-turbo-frame=#{frame}]", { minimum: 1 },
        "#{path} renders ##{frame} but nothing navigates it"
    end
  end

  # Reports is the one page where two filters share a frame and could drop each
  # other's params.
  test "reports keeps both of its filters through a frame request" do
    mechanic = users(:andrii)

    get reports_path(period: "month", mechanic_id: mechanic.id),
        headers: { "Turbo-Frame" => "reports_content" }

    assert_select "turbo-frame#reports_content"
    assert_select "select[name=mechanic_id] option[selected][value=?]", mechanic.id.to_s
    assert_select "a.bg-gray-900", text: "Місяць"
  end

  test "pagination stays inside the frame instead of reloading the page" do
    12.times do |i|
      Client.create!(name: "Клієнт #{i}", phone: "38050000#{format('%04d', i)}")
    end

    get clients_path
    assert_select "a[data-turbo-frame=clients_list]", text: "›"

    get clients_path(page: 2), headers: { "Turbo-Frame" => "clients_list" }
    assert_select "turbo-frame#clients_list"
  end

  test "filtering actually filters inside the frame" do
    get parts_path(category_id: Category.part.active.first.id), headers: { "Turbo-Frame" => "parts_list" }

    assert_response :success
    assert_select "turbo-frame#parts_list tbody tr"
  end

  # Streams target ids document-wide, so moving a tbody inside a frame must not
  # break the add-item flow that updates it.
  test "a turbo_stream refresh still reaches a tbody that now sits inside a frame" do
    post parts_path, params: { part: { name: "Нова запчастина", base_price: 100,
                                       category_id: Category.part.active.first.id } },
         headers: { "Accept" => "#{Mime[:turbo_stream]}, text/html" }

    assert_response :success
    assert_select "turbo-stream[target=parts_rows] template", html: /Нова запчастина/
  end
end
