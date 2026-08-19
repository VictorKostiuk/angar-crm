require "test_helper"

class CatalogSearchTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           accepted_at: Time.current, status: :in_progress)

    @brakes = Category.create!(name: "Гальма", kind: :part)
    @drive = Category.create!(name: "Трансмісія", kind: :part)
    @pads = Part.create!(name: "Колодки Shimano", category: @brakes, base_price: 300)
    @chain = Part.create!(name: "Ланцюг Shimano", category: @drive, base_price: 900)

    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  test "the modal offers a pill per category and one controller owns both params" do
    get new_order_order_part_path(@order), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "[data-controller=frame-search]" do
      assert_select "input[data-frame-search-target=input]"
      assert_select "button[data-frame-search-target=pill]", Category.part.active.count + 1 # + "Усі"
      assert_select "button[data-category-id=?]", @brakes.id.to_s, text: "Гальма"
      assert_select "button[data-category-id='']", text: "Усі"
    end
    # The search input must not be a form field — the pills and the box have to
    # go through the same controller or each clobbers the other's param.
    assert_select "[data-controller=frame-search] form", 0
  end

  test "the search endpoint filters by category, by query, and by both together" do
    def names = css_select("turbo-frame span.text-gray-900").map { |n| n.text.strip }

    # Unfiltered also returns the catalog fixtures, so assert membership here
    # and exact sets only where the filter should isolate our own records.
    get search_parts_path(order_id: @order.id)
    assert_includes names, @chain.name
    assert_includes names, @pads.name

    get search_parts_path(order_id: @order.id, category_id: @brakes.id)
    assert_equal [ @pads.name ], names

    get search_parts_path(order_id: @order.id, q: "Shimano")
    assert_equal [ @chain.name, @pads.name ].sort, names.sort

    # Both directions of the cross-preservation: filter-then-type…
    get search_parts_path(order_id: @order.id, category_id: @drive.id, q: "Shimano")
    assert_equal [ @chain.name ], names

    # …and type-then-filter lands on the same request.
    get search_parts_path(order_id: @order.id, q: "Shimano", category_id: @brakes.id)
    assert_equal [ @pads.name ], names
  end

  test "results stay inside the frame they are loaded into" do
    get search_parts_path(order_id: @order.id, category_id: @brakes.id),
        headers: { "Turbo-Frame" => "order_part_search_results" }

    assert_select "turbo-frame#order_part_search_results"
  end

  # The services modal shares the partial but loads its own @categories — a
  # broken lookup there would silently render an "Усі"-only bar.
  test "the services modal gets the same box and its own category pills" do
    Category.create!(name: "Гальмівна система", kind: :service)

    get new_order_order_work_path(@order), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "h2", text: "Додати послугу"
    assert_select "[data-controller=frame-search] input[data-frame-search-target=input]"
    assert_select "button[data-frame-search-target=pill]", Category.service.active.count + 1
    assert_select "button[data-category-id='']", text: "Усі"
  end

  # overflow-y:auto hides the bar on macOS until you scroll, so a list that
  # continues below the fold looks like it simply ends.
  test "the scroll containers keep their bar painted" do
    get new_order_order_part_path(@order), headers: { "Turbo-Frame" => "modal" }

    assert_select "turbo-frame#order_part_search_results.scroll-always"
    assert_select "turbo-frame#order_part_search_results.overflow-y-auto", 0
    assert_select ".scroll-always", 2 # modal body + results list
  end
end
