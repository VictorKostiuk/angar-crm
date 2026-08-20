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
end
