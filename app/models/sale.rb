class Sale < ApplicationRecord
  belongs_to :sold_by, class_name: "User"
  belongs_to :client, optional: true
  has_many :sale_items, dependent: :destroy, inverse_of: :sale

  # A line needs either a catalogue item or a typed name — an empty row is just
  # an unused row on the form, not an error.
  accepts_nested_attributes_for :sale_items, allow_destroy: true,
                                reject_if: ->(attrs) {
                                  (attrs[:part_id].blank? && attrs[:name].blank?) || attrs[:quantity].to_i <= 0
                                }

  validates :sold_at, presence: true
  validate :must_have_at_least_one_item

  scope :ordered, -> { order(sold_at: :desc, created_at: :desc) }
  scope :in_range, ->(range) { where(sold_at: range) }

  # The seller's cut of a counter sale. Deliberately its own rate, not
  # payroll_percent (D40): labour and retail margin are priced separately, and
  # the per-order minimum (D37) has no meaning for a sale.
  def commission
    (total * sold_by.sales_percent / 100).round
  end

  private
    def must_have_at_least_one_item
      errors.add(:base, "Додайте хоча б одну позицію") if sale_items.reject(&:marked_for_destruction?).empty?
    end
end
