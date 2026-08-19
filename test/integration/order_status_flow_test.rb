require "test_helper"

class OrderStatusFlowTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @mechanic = users(:andrii)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           accepted_at: Time.current, status: :intake)
    @order.order_works.create!(name: "Робота", quantity: 1, price: 250)

    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  # What Turbo actually sends when submitting a form.
  def turbo_headers
    { "Accept" => "#{Mime[:turbo_stream]}, text/html, application/xhtml+xml" }
  end

  # The status form lives inside the #modal Turbo Frame, so a bare redirect
  # would only swap that frame back to empty and leave the page stale — the
  # user had to reload to see the new status.
  test "changing status streams every region that depends on it" do
    patch order_status_path(@order),
          params: { status: "in_progress", comment: "Почали" },
          headers: turbo_headers

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type

    assert_select "turbo-stream[action=update][target=order_header] template",
      html: /#{I18n.t("statuses.order.in_progress")}/

    # ChangeStatus builds the log row outside the association, so make sure a
    # fresh query picks it up.
    assert_select "turbo-stream[action=update][target=order_status_timeline] template", html: /Почали/

    assert_select "turbo-stream[action=update][target=order_totals]"
    assert_select "turbo-stream[action=update][target=flash] template", html: /Статус оновлено/
    assert_select "turbo-stream[action=update][target=modal]"

    # Board: the card leaves its old section and lands in the new one.
    assert_select "turbo-stream[action=remove][target=board_card_#{@order.id}]"
    assert_select "turbo-stream[action=prepend][target=board_section_in_progress_cards]" do
      assert_select "template", html: /#{@order.bike.name}/
    end

    # Literal counts, not a re-derivation of the template's own query — the
    # order set up here is the only open order.
    { "intake" => "0", "waiting_approval" => "0", "in_progress" => "1",
      "waiting_parts" => "0", "waiting_pickup" => "0" }.each do |status, count|
      assert_select "turbo-stream[action=update][target=board_section_#{status}_count] template",
        text: count
    end

    assert @order.reload.in_progress?

    # The symptom that was reported: the page itself, freshly loaded, agrees.
    get order_path(@order)
    assert_select "#order_header", html: /#{I18n.t("statuses.order.in_progress")}/

    # And the board really carries the ids the streams above target — otherwise
    # a drifted id would make every one of them a silent no-op.
    get root_path
    assert_select "#board_section_in_progress_count", text: "1"
    assert_select "#board_section_in_progress_cards #board_card_#{@order.id}"
    assert_select "#board_section_intake_count", text: "0"
  end

  test "a status outside the open set re-renders the modal form with the error" do
    patch order_status_path(@order), params: { status: "closed" }, headers: turbo_headers

    assert_response :unprocessable_entity
    assert_match "недоступний для цього замовлення", response.body
    assert @order.reload.intake?
  end

  test "closing takes the card off the board and drops the open-status actions" do
    @order.update!(mechanic: @mechanic, status: :waiting_pickup, payment_status: :paid, payment_method: :cash)

    patch order_closure_path(@order), headers: turbo_headers

    assert_response :success
    assert_select "turbo-stream[action=remove][target=board_card_#{@order.id}]"
    assert_select "turbo-stream[action=prepend]", false, "a closed order must not be re-added to the board"
    assert_select "turbo-stream[action=update][target=order_header] template",
      html: /#{I18n.t("statuses.order.closed")}/

    assert @order.reload.closed?
  end

  test "closing while blocked re-renders the checklist instead of streaming" do
    patch order_closure_path(@order), headers: turbo_headers

    assert_response :unprocessable_entity
    assert_select "turbo-stream", false, "a blocked close must not stream page updates"
    assert_select "button[type=submit][disabled]"
    refute @order.reload.closed?
  end

  test "cancelling streams the board removal and the cancelled badge" do
    patch order_cancellation_path(@order), params: { reason: "Клієнт передумав" }, headers: turbo_headers

    assert_response :success
    assert_select "turbo-stream[action=remove][target=board_card_#{@order.id}]"
    assert_select "turbo-stream[action=prepend]", false, "a cancelled order must not be re-added to the board"
    assert_select "turbo-stream[action=update][target=order_header] template",
      html: /#{I18n.t("statuses.order.cancelled")}/

    assert @order.reload.cancelled?
    assert_equal "Клієнт передумав", @order.cancel_reason
  end

  test "cancelling without a reason re-renders the modal form with the error" do
    patch order_cancellation_path(@order), headers: turbo_headers

    assert_response :unprocessable_entity
    refute @order.reload.cancelled?
  end
end
