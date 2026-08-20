require "test_helper"

# "The owner also turns wrenches": works_as_mechanic makes a user assignable and
# reportable as a mechanic without touching their permissions, which stay keyed
# on role (§7).
class OwnerAsMechanicFlowTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           accepted_at: Time.current, status: :in_progress)
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  # This validation exists because an owner really did get picked from an
  # unfiltered dropdown once (app/models/order.rb). Ticking the box is now the
  # only thing that makes it legal — both directions matter.
  test "an order takes the owner as mechanic only once they work as one" do
    @order.mechanic = @owner
    refute @order.valid?
    assert_includes @order.errors.full_messages.to_sentence, "має бути механіком"

    @owner.update!(works_as_mechanic: true)
    @order.reload.mechanic = @owner
    assert @order.valid?
    assert @order.save
  end

  test "a payout can only be recorded for the owner once they work as one" do
    payout = PayrollPayout.new(user: @owner, recorded_by: @owner, amount: 500, period_month: Date.current)
    refute payout.valid?

    @owner.update!(works_as_mechanic: true)
    assert payout.valid?
  end

  test "the flagged owner joins the mechanic dropdowns and the roster" do
    @owner.update!(works_as_mechanic: true, payroll_percent: 40)
    sign_in(@owner)

    get order_path(@order)
    assert_select "select[name=?] option", "order[mechanic_id]", text: @owner.name

    get new_order_path
    assert_select "select[name=accepted_by_id] option", text: @owner.name

    get mechanics_path
    assert_select "h2", text: @owner.name
    assert_select "h2", text: @mechanic.name

    get mechanic_path(@owner)
    assert_response :success

    get finances_path
    assert_select "select[name=mechanic_id] option", text: @owner.name

    # The roster is where the owner manages people, so adding one starts here.
    get mechanics_path
    assert_select "a[href=?]", users_path, text: "+ Додати користувача"

    # The path the user actually clicks — the dropdown rendering is not enough.
    patch order_path(@order), params: { order: { mechanic_id: @owner.id } }
    assert_equal @owner, @order.reload.mechanic
  end

  test "an unflagged owner is still rejected on the assignment path itself" do
    sign_in(@owner)

    patch order_path(@order), params: { order: { mechanic_id: @owner.id } }

    assert_response :unprocessable_entity
    assert_nil @order.reload.mechanic
  end

  test "an unflagged owner stays out of the mechanic lists" do
    sign_in(@owner)

    get mechanics_path
    assert_select "h2", text: @owner.name, count: 0
    assert_select "h2", text: @mechanic.name

    # 404 from the finder scope, not from the authorization guard — an owner
    # passes require_own_card_or_owner and simply isn't in the roster.
    get mechanic_path(@owner)
    assert_response :not_found
  end

  test "the flagged owner gets stats and payroll rows like any mechanic" do
    @owner.update!(works_as_mechanic: true, payroll_percent: 50)
    @order.update!(mechanic: @owner)
    @order.order_works.create!(name: "Робота", quantity: 1, price: 400, mechanic: @owner)
    @order.update!(payment_status: :paid, payment_method: :cash)
    Orders::Close.call(order: @order)

    rows = Reports::MechanicStats.call(range: Date.current.all_month)
    row = rows.find { |r| r.mechanic == @owner }

    assert row, "the flagged owner must get a stats row"
    assert_equal 400, row.works_total
    assert_equal 200, row.payout
    assert_equal 200, Finances::OutstandingPayroll.call(mechanic: @owner, month: Date.current)
  end

  # users#update runs params through compact_blank, and an unchecked box posts
  # "0" — which must survive that filter or the flag could never be turned off.
  test "the settings screen can turn the flag on and back off" do
    sign_in(@owner)

    patch user_path(@owner), params: { user: { works_as_mechanic: "1", payroll_percent: "40" } }
    assert @owner.reload.works_as_mechanic?

    # The "% ЗП" column keys on assignability now, not on the mechanic role.
    follow_redirect!
    assert_select "#user_row_#{@owner.id} td", text: "40%"

    patch user_path(@owner), params: { user: { works_as_mechanic: "0" } }
    refute @owner.reload.works_as_mechanic?
  end

  # Permissions are role-based and must not move with the flag.
  test "the flag grants no permissions of its own" do
    @owner.update!(works_as_mechanic: true)
    sign_in(@owner)

    # An owner sees the whole roster; a mechanic is bounced to their own card.
    get mechanics_path
    assert_response :success

    sign_in(@mechanic)
    get mechanics_path
    assert_redirected_to mechanic_path(@mechanic)
    assert_select "a", text: "+ Додати користувача", count: 0

    get mechanic_path(@owner)
    assert_redirected_to root_path
  end
end
