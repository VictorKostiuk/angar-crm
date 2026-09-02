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

  before_validation :merge_duplicate_items, on: :create

  scope :ordered, -> { order(sold_at: :desc, created_at: :desc) }
  scope :in_range, ->(range) { where(sold_at: range) }

  # The seller's cut of a counter sale. Deliberately its own rate, not
  # payroll_percent (D40): labour and retail margin are priced separately, and
  # the per-order minimum (D37) has no meaning for a sale.
  def commission
    (total * sold_by.sales_percent / 100).round
  end

  private
    # Picking the same catalogue item on two rows means "two of it", not two
    # lines. It was never wrong money — two −1 movements net the same stock and
    # book the same cost as one −2 — but the sale read «Каретка × 1, Каретка ×
    # 1» and the movements ledger carried twice the rows for one position.
    #
    # Only lines agreeing on BOTH the part and the effective price merge: a
    # deliberately different price on the second row is a different line, not a
    # duplicate, and merging it would silently discard one of the two prices.
    # The price is resolved the same way SaleItem#default_from_part resolves it,
    # since that callback has not run yet when this one does.
    #
    # One-off lines never merge — they have no catalogue entry to match on, and
    # two rows typed with the same name are not necessarily the same thing.
    def merge_duplicate_items
      first_of = {}

      sale_items.each do |item|
        next if item.part_id.blank? || item.marked_for_destruction?

        key = [ item.part_id, item.price.presence || item.part&.base_price ]

        if (original = first_of[key])
          original.quantity = original.quantity.to_i + item.quantity.to_i
          item.mark_for_destruction
        else
          first_of[key] = item
        end
      end
    end

    def must_have_at_least_one_item
      errors.add(:base, "Додайте хоча б одну позицію") if sale_items.reject(&:marked_for_destruction?).empty?
    end
end
