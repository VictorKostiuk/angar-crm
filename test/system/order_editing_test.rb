require "application_system_test_case"

class OrderEditingSystemTest < ApplicationSystemTestCase
  setup do
    @owner = users(:owner)
    @order = Order.create!(client: clients(:ivan), bike: bikes(:trek), accepted_by: @owner,
                           mechanic: users(:andrii), accepted_at: Time.current, status: :in_progress)
    @work = @order.order_works.create!(name: "Заміна ланцюга", quantity: 1, price: 250)
    @part = @order.order_parts.create!(name: "Ланцюг КМС", quantity: 1, price: 950)
  end

  # This one broke twice: the amount applied but the picker reset to «Без знижки».
  test "picking a discount applies it and the select still shows it afterwards" do
    Discount.create!(name: "Постійний клієнт", kind: :percentage, value: 10, applies_to: :all)
    sign_in @owner
    visit order_path(@order)

    assert_text "1 200 грн"
    select_discount "Постійний клієнт"

    assert_text "−120 грн"                                   # Turbo re-rendered
    assert_text "1 080 грн"
    assert_discount_selected "Постійний клієнт"

    visit order_path(@order)                                 # and after a reload
    assert_discount_selected "Постійний клієнт"
  end

  test "clearing the discount puts the select back to Без знижки" do
    Discount.create!(name: "Постійний клієнт", kind: :percentage, value: 10, applies_to: :all)
    sign_in @owner
    visit order_path(@order)

    select_discount "Постійний клієнт"
    assert_text "−120 грн"

    select_discount "Без знижки"
    assert_no_text "−120 грн"
    assert_text "1 200 грн"
  end

  # The <form> used to sit directly inside <tr>; the parser emptied it, so
  # editing a price posted nothing at all.
  # The discount is derived server-side now, so a percentage must follow the
  # order as it grows instead of freezing at what it was when picked.
  test "a percentage discount follows the order when a line is added" do
    Discount.create!(name: "Десятка", kind: :percentage, value: 10, applies_to: :all)
    sign_in @owner
    visit order_path(@order)

    select_discount "Десятка"
    assert_text "−120 грн"          # 10% of 1 200

    within("#order_parts_rows") { fill_in "order_part[price]", with: "1950" }
    find("body").click
    assert_text "−220 грн"          # 10% of 2 200, not the old 120
  end

  test "a services-only discount ignores the parts on the order" do
    Discount.create!(name: "Лише послуги", kind: :percentage, value: 10, applies_to: :services)
    sign_in @owner
    visit order_path(@order)

    select_discount "Лише послуги"
    assert_text "−25 грн"           # 10% of 250 послуги, not of 1 200
    assert_text "1 175 грн"
  end

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
    # The option text carries the value and scope, so match on the name only.
    def select_discount(name)
      option = find("select[name='order[discount_record_id]'] option", text: /\A#{Regexp.escape(name)}/, match: :first)
      select option.text, from: "order[discount_record_id]"
    end

    def assert_discount_selected(name)
      assert_match(/\A#{Regexp.escape(name)}/,
                   find("select[name='order[discount_record_id]'] option[selected]", visible: :all).text.strip)
    end
end
