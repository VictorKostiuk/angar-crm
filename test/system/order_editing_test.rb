require "application_system_test_case"

class OrderEditingSystemTest < ApplicationSystemTestCase
  setup do
    @owner = users(:owner)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           accepted_at: Time.current, status: :in_progress)
    @work = @order.order_works.create!(name: "Заміна ланцюга", quantity: 1, price: 250)
    @part = @order.order_parts.create!(name: "Ланцюг КМС", quantity: 1, price: 950)
  end

  # This one broke twice: the amount applied but the picker reset to «Без знижки».
  test "picking a discount applies it and the select still shows it afterwards" do
    Discount.create!(name: "Постійний клієнт", kind: :percentage, value: 10)
    sign_in @owner
    visit order_path(@order)

    assert_text "1 200 грн"
    select "Постійний клієнт (10%)", from: "order[discount_record_id]"

    assert_text "−120 грн"                                   # Turbo re-rendered
    assert_text "1 080 грн"
    assert_select_value "order[discount_record_id]", "Постійний клієнт (10%)"

    visit order_path(@order)                                 # and after a reload
    assert_select_value "order[discount_record_id]", "Постійний клієнт (10%)"
  end

  test "clearing the discount puts the select back to Без знижки" do
    Discount.create!(name: "Постійний клієнт", kind: :percentage, value: 10)
    sign_in @owner
    visit order_path(@order)

    select "Постійний клієнт (10%)", from: "order[discount_record_id]"
    assert_text "−120 грн"

    select "Без знижки", from: "order[discount_record_id]"
    assert_no_text "−120 грн"
    assert_text "1 200 грн"
  end

  # The <form> used to sit directly inside <tr>; the parser emptied it, so
  # editing a price posted nothing at all.
  test "editing a price recalculates the order total" do
    sign_in @owner
    visit order_path(@order)

    within("#order_parts_rows") { fill_in "order_part[price]", with: "500" }
    find("body").click # blur fires change

    assert_text "750 грн" # 250 послуги + 500 запчастини
  end

  test "editing a quantity recalculates the order total" do
    sign_in @owner
    visit order_path(@order)

    within("#order_works_rows") { fill_in "order_work[quantity]", with: "3" }
    find("body").click

    assert_text "1 700 грн" # 750 works + 950 parts
  end

  private
    def assert_select_value(name, expected)
      assert_equal expected, find("select[name='#{name}'] option[selected]", visible: :all).text.strip
    end
end
