require "test_helper"

class SalesFlowTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @seller = users(:andrii)
    @seller.update!(sales_percent: 10)
    @part = Part.create!(name: "Камера 700x35", category: Category.part.active.first,
                         base_price: 180, purchase_price: 100)
    StockMovement.create!(part: @part, kind: :receipt, quantity: 10, user: @owner)
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  def sell!(quantity: 2, price: 180)
    post sales_path, params: { sale: { client_id: clients(:ivan).id,
                                       sale_items_attributes: { "0" => { part_id: @part.id, quantity: quantity, price: price } } } }
  end

  test "a sale records lines, totals and takes the goods off the shelf" do
    sign_in(@seller)

    assert_difference -> { Sale.count }, 1 do
      assert_difference -> { @part.reload.stock_quantity }, -2 do
        sell!
      end
    end

    sale = Sale.order(:id).last
    assert_equal 360, sale.total
    assert_equal @seller, sale.sold_by
    assert_equal 36, sale.commission, "10% of 360"

    movement = StockMovement.order(:id).last
    assert movement.sale?, "a sale is its own stock kind, not consumption"
    assert_equal(-2, movement.quantity)
  end

  # Selling books the purchase price as cost at the same moment the revenue is
  # recognised — otherwise profit is overstated by the whole cost of goods.
  test "a sale books its cost of goods once" do
    sign_in(@seller)

    assert_difference -> { Expense.count }, 1 do
      sell!
    end

    expense = Expense.order(:id).last
    assert_equal 200, expense.amount, "2 × purchase_price 100"
    assert_equal "Собівартість продажу", expense.category
    assert expense.auto_logged?
  end

  # A write-off has no revenue behind it, so it must not book a cost.
  test "a write-off still books nothing" do
    sign_in(@owner)

    assert_no_difference -> { Expense.count } do
      post stock_movements_path, params: { stock_movement: { part_id: @part.id, kind: "write_off", quantity: 3 } }
    end

    assert_equal(-3, StockMovement.order(:id).last.quantity, "a write-off is always negative")
    assert_equal 7, @part.reload.stock_quantity
  end

  test "a part with no purchase price sells without booking a cost" do
    @part.update!(purchase_price: nil)
    sign_in(@seller)

    assert_no_difference -> { Expense.count } do
      assert_difference -> { Sale.count }, 1 do
        sell!
      end
    end
  end

  # The form renders the price field from the record, so a column default of 0
  # meant it submitted "0.0" rather than empty — blank? was false, the part's
  # price was never substituted, and the sale recorded 0 грн. Found in a browser,
  # invisible to every params-level test that passed a price explicitly.
  test "a line with no price typed falls back to the part's price" do
    sign_in(@seller)

    post sales_path, params: { sale: { sale_items_attributes: {
      "0" => { part_id: @part.id, quantity: "2", price: SaleItem.new.price.to_s }
    } } }

    sale = Sale.order(:id).last
    assert_equal 180, sale.sale_items.first.price, "should fall back to base_price"
    assert_equal 360, sale.total
  end

  test "a deliberately free line stays free" do
    sign_in(@seller)

    post sales_path, params: { sale: { sale_items_attributes: {
      "0" => { part_id: @part.id, quantity: "1", price: "0" }
    } } }

    assert_equal 0, Sale.order(:id).last.total
  end

  # Not everything sold over the counter is in the catalogue — the order screen
  # already allows a one-off line, and the sale screen now matches.
  test "a one-off line sells without touching stock or booking a cost" do
    sign_in(@seller)

    assert_no_difference [ -> { StockMovement.count }, -> { Expense.count } ] do
      assert_difference -> { Sale.count }, 1 do
        post sales_path, params: { sale: { sale_items_attributes: {
          "0" => { part_id: "", name: "Ремонт камери на місці", quantity: "1", price: "150" }
        } } }
      end
    end

    item = Sale.order(:id).last.sale_items.first
    assert item.custom?
    assert_equal "Ремонт камери на місці", item.name
    assert_equal 150, Sale.order(:id).last.total
  end

  test "a one-off line and a catalogue line on the same sale" do
    sign_in(@seller)

    post sales_path, params: { sale: { sale_items_attributes: {
      "0" => { part_id: @part.id, quantity: "1", price: "" },
      "1" => { part_id: "", name: "Робота на місці", quantity: "1", price: "150" }
    } } }

    sale = Sale.order(:id).last
    assert_equal 330, sale.total, "180 зі складу + 150 своя позиція"
    assert_equal 1, sale.sale_items.reject(&:custom?).size
    assert_equal(-1, StockMovement.order(:id).last.quantity, "only the catalogue line moves stock")
    assert_equal 9, @part.reload.stock_quantity
  end

  # The add-a-row button generates the child index client-side. params.expect's
  # array form only accepts index-like keys, so a non-numeric one is dropped
  # whole — silently, because the rest of the sale still saves.
  test "rows keyed the way the add button keys them all arrive" do
    sign_in(@seller)

    post sales_path, params: { sale: { sale_items_attributes: {
      "0" => { part_id: @part.id, quantity: "1", price: "180" },
      Time.current.to_i.to_s => { part_id: "", name: "Своя позиція", quantity: "1", price: "150" }
    } } }

    assert_equal 2, Sale.order(:id).last.sale_items.count, "an added row must not be dropped"
    assert_equal 330, Sale.order(:id).last.total
  end

  test "a line with neither a part nor a name is ignored, not an error" do
    sign_in(@seller)

    post sales_path, params: { sale: { sale_items_attributes: {
      "0" => { part_id: @part.id, quantity: "1", price: "180" },
      "1" => { part_id: "", name: "", quantity: "1", price: "" }
    } } }

    assert_equal 1, Sale.order(:id).last.sale_items.count
  end

  test "a one-off line without a name is rejected" do
    sign_in(@seller)

    assert_no_difference -> { Sale.count } do
      post sales_path, params: { sale: { sale_items_attributes: {
        "0" => { part_id: "", name: "", quantity: "1", price: "150" }
      } } }, headers: { "Accept" => "#{Mime[:turbo_stream]}, text/html, application/xhtml+xml" }
    end
    assert_response :unprocessable_entity
  end

  test "a sale needs at least one line" do
    sign_in(@seller)

    assert_no_difference -> { Sale.count } do
      post sales_path, params: { sale: { client_id: clients(:ivan).id } },
           headers: { "Accept" => "#{Mime[:turbo_stream]}, text/html, application/xhtml+xml" }
    end
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=update][target=modal] template", html: /Додайте хоча б одну позицію/
  end

  test "every role can sell, and the button is on the workshop board" do
    sign_in(@seller)

    get root_path
    assert_select "a[href=?]", new_sale_path, text: "+ Новий продаж"

    get sales_path
    assert_response :success
    get new_sale_path, headers: { "Turbo-Frame" => "modal" }
    assert_response :success
  end

  test "stock stays owner-side" do
    sign_in(@seller)

    get stock_path
    assert_redirected_to root_path
  end

  test "the sales list totals the period" do
    sign_in(@seller)
    sell!(quantity: 1, price: 180)
    sell!(quantity: 1, price: 180)

    get sales_path(period: "month")

    assert_select "p", text: ApplicationController.helpers.money(360)
    assert_select "p", text: ApplicationController.helpers.money(36)
  end

  # Reported: picking «Каретка» on two rows recorded it twice instead of adding
  # up, so the list read «Каретка × 1, Каретка × 1» and the movements ledger
  # carried two rows for one position.
  test "the same catalogue item picked twice becomes one line of two" do
    sign_in(@seller)

    assert_difference -> { SaleItem.count }, 1, "the duplicate row must not be inserted at all" do
      assert_difference -> { @part.reload.stock_quantity }, -3 do
        post sales_path, params: { sale: { sale_items_attributes: {
          "0" => { part_id: @part.id, quantity: 1, price: 180 },
          "1" => { part_id: @part.id, quantity: 2, price: 180 } } } }
      end
    end

    sale = Sale.order(:id).last
    item = sale.sale_items.sole
    assert_equal 3, item.quantity
    assert_equal 540, item.total, "the merged quantity has to reprice the line"
    assert_equal 540, sale.total
    assert_equal 1, StockMovement.where(kind: :sale, part: @part).count
  end

  # A different price on the second row is a deliberate distinction, not a
  # duplicate — merging it would silently throw one of the two prices away.
  test "the same item at two different prices stays two lines" do
    sign_in(@seller)

    assert_difference -> { SaleItem.count }, 2 do
      post sales_path, params: { sale: { sale_items_attributes: {
        "0" => { part_id: @part.id, quantity: 1, price: 180 },
        "1" => { part_id: @part.id, quantity: 1, price: 150 } } } }
    end

    assert_equal 330, Sale.order(:id).last.total
  end

  # One-off lines have no catalogue entry to match on, and two rows typed with
  # the same name are not necessarily the same thing.
  test "one-off lines are never merged" do
    sign_in(@seller)

    assert_difference -> { SaleItem.count }, 2 do
      post sales_path, params: { sale: { sale_items_attributes: {
        "0" => { name: "Ремонт на місці", quantity: 1, price: 100 },
        "1" => { name: "Ремонт на місці", quantity: 1, price: 100 } } } }
    end
  end
end
