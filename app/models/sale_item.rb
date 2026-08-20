class SaleItem < ApplicationRecord
  belongs_to :sale, inverse_of: :sale_items
  belongs_to :part
  has_one :stock_movement, dependent: :nullify

  validates :quantity, numericality: { greater_than: 0, only_integer: true }
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  before_validation :default_from_part
  after_create :move_stock

  private
    def default_from_part
      return if part.blank?

      self.name = part.name if name.blank?
      self.price = part.base_price if price.blank?
      self.total = price.to_d * quantity.to_i
    end

    # Stock leaves the shelf the moment the sale is recorded. `sale` is its own
    # kind so Finances::LogGoodsCost books the purchase price as cost of sale,
    # while a write-off or adjustment still books nothing.
    def move_stock
      StockMovement.create!(part: part, sale_item: self, user: sale.sold_by,
                            kind: :sale, quantity: -quantity)
    end
end
