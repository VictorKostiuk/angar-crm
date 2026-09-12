require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "reseeding preserves account changes and catalog prices" do
    capture_io { Rails.application.load_seed }
    owner = User.find_by!(email_address: "angarvelokafe@gmail.com")
    owner.update!(name: "Змінене ім'я", password: "changed-password", active: false)
    service = Service.find_by!(name: "Повне ТО велосипеда")
    service.update!(base_price: 3210)
    part = Part.find_by!(name: "Ланцюг КМС X10")
    part.update!(base_price: 1234)

    assert_no_difference [ "User.count", "Service.count", "Part.count", "Category.count" ] do
      output, = capture_io { Rails.application.load_seed }
      refute_includes output, "changed-password"
      refute_includes output, "password123"
    end

    assert owner.reload.authenticate("changed-password")
    assert_equal "Змінене ім'я", owner.name
    refute owner.active?
    assert_equal 3210, service.reload.base_price
    assert_equal 1234, part.reload.base_price
  end
end
