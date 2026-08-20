class StockMovement < ApplicationRecord
  belongs_to :part
  belongs_to :user, optional: true # nil for system-generated consumption
  belongs_to :order, optional: true # set only when kind: consumption
  belongs_to :sale_item, optional: true # set only when kind: sale
  has_one :expense, dependent: :nullify

  enum :kind, { receipt: 0, write_off: 1, consumption: 2, adjustment: 3, sale: 4 }

  validates :quantity, numericality: { other_than: 0, only_integer: true }

  after_create :recalculate_part_stock
  after_create :log_goods_cost

  private
    def recalculate_part_stock
      Parts::RecalculateStock.call(part)
    end

    def log_goods_cost
      Finances::LogGoodsCost.call(self)
    end
end
