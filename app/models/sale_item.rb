class SaleItem < ApplicationRecord
  belongs_to :sale, inverse_of: :sale_items
  # Optional: a one-off line ("своя позиція") has no catalogue entry, mirroring
  # the custom line the order screen allows.
  belongs_to :part, optional: true
  has_one :stock_movement, dependent: :nullify

  validates :name, presence: true
  validates :quantity, numericality: { greater_than: 0, only_integer: true }
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  before_validation :default_from_part
  after_create :move_stock

  def custom?
    part_id.nil?
  end

  private
    def default_from_part
      if part.present?
        self.name = part.name if name.blank?
        # blank, not zero: a deliberately free line stays free.
        self.price = part.base_price if price.blank?
      end

      self.total = price.to_d * quantity.to_i
    end

    # Only a catalogue item leaves the shelf. A one-off line was never in stock,
    # so there is nothing to decrement — and no purchase price, so
    # Finances::LogGoodsCost books no cost of sale for it either.
    def move_stock
      return if custom?

      StockMovement.create!(part: part, sale_item: self, user: sale.sold_by,
                            kind: :sale, quantity: -quantity)
    end
end
