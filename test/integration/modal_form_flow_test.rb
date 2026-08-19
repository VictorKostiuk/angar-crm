require "test_helper"

# The create/edit modals redirect to a *different* page on success (the new
# client's page, the parts index, the mechanic's card), so unlike the order
# modals they can't be fixed by streaming regions back — the forms break out of
# the #modal frame instead (data-turbo-frame="_top") and errors come back as a
# Turbo Stream that rebuilds the dialog.
class ModalFormFlowTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @client = clients(:ivan)
    post session_path, params: { email_address: @owner.email_address, password: "password123" }
  end

  # What Turbo actually sends when submitting a form.
  def turbo_headers
    { "Accept" => "#{Mime[:turbo_stream]}, text/html, application/xhtml+xml" }
  end

  # The dialog has to come back rebuilt — frame wrapper gone, <dialog> and the
  # breakout form intact — not as a full-page render that would blow away the
  # page underneath.
  def assert_modal_error(message)
    assert_response :unprocessable_entity
    assert_equal Mime[:turbo_stream], response.media_type
    assert_select "turbo-stream[action=update][target=modal] template" do |templates|
      html = templates.first.to_s
      assert_match(/data-controller="dialog"/, html)
      assert_match(/data-turbo-frame="_top"/, html)
      assert_match(/bg-red-50/, html, "the dialog must come back showing the error box")
      assert_match(/#{message}/, html)
    end
  end

  test "every modal form breaks out of the #modal frame so its redirect lands on the whole page" do
    [ new_client_path, edit_client_path(@client), new_client_bike_path(@client),
      new_category_path(kind: :part), new_mechanic_payroll_payout_path(users(:andrii)) ].each do |path|
      get path, headers: { "Turbo-Frame" => "modal" }
      assert_response :success
      assert_select "form[data-turbo-frame=_top]", 1, "#{path} must not keep its form inside the modal frame"
    end
  end

  test "creating a client navigates to the new client and reports the error in the dialog" do
    post clients_path, params: { client: { name: "", phone: "" } }, headers: turbo_headers
    assert_modal_error "Ім'я не може бути порожнім"

    assert_difference -> { Client.count }, 1 do
      post clients_path, params: { client: { name: "Нова", phone: "097 111 22 33" } }, headers: turbo_headers
    end
    assert_redirected_to Client.order(:id).last
  end

  test "updating a client redirects and reports the error in the dialog" do
    patch client_path(@client), params: { client: { name: "" } }, headers: turbo_headers
    assert_modal_error "Ім'я не може бути порожнім"
    assert_equal clients(:ivan).name, @client.reload.name

    patch client_path(@client), params: { client: { name: "Іван П." } }, headers: turbo_headers
    assert_redirected_to @client
    assert_equal "Іван П.", @client.reload.name
  end

  test "adding a bike redirects to the client and reports the error in the dialog" do
    post client_bikes_path(@client), params: { bike: { name: "" } }, headers: turbo_headers
    assert_modal_error "Назва не може бути порожнім"

    assert_difference -> { @client.bikes.count }, 1 do
      post client_bikes_path(@client), params: { bike: { name: "Cube Aim" } }, headers: turbo_headers
    end
    assert_redirected_to @client
  end

  test "adding a category redirects to its list and reports the error in the dialog" do
    post categories_path, params: { category: { name: "", kind: "part" } }, headers: turbo_headers
    assert_modal_error "Назва не може бути порожнім"

    post categories_path, params: { category: { name: "Гальма", kind: "part" } }, headers: turbo_headers
    assert_redirected_to parts_path

    post categories_path, params: { category: { name: "Ремонт", kind: "service" } }, headers: turbo_headers
    assert_redirected_to services_path
  end

  test "recording a payout redirects to the mechanic and reports the error in the dialog" do
    mechanic = users(:andrii)

    post mechanic_payroll_payouts_path(mechanic),
         params: { payroll_payout: { amount: "", period_month: "" } }, headers: turbo_headers
    assert_modal_error "Сума має бути числом"

    assert_difference -> { mechanic.payroll_payouts.count }, 1 do
      post mechanic_payroll_payouts_path(mechanic),
           params: { payroll_payout: { amount: "1000", period_month: Date.current.beginning_of_month } },
           headers: turbo_headers
    end
    assert_redirected_to mechanic_path(mechanic)
  end
end
