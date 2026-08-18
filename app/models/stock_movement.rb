class StockMovement < ApplicationRecord
  belongs_to :part
  belongs_to :user, optional: true # nil for system-generated consumption
  belongs_to :order, optional: true # set only when kind: consumption

  enum :kind, { receipt: 0, write_off: 1, consumption: 2, adjustment: 3 }

  validates :quantity, numericality: { other_than: 0, only_integer: true }

  after_create :recalculate_part_stock

  private
    def recalculate_part_stock
      Parts::RecalculateStock.call(part)
    end
end
