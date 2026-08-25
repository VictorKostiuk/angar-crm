class Discount < ApplicationRecord
  enum :kind, { percentage: 0, fixed_amount: 1 }
  # What the discount comes off: services only, parts only, or the whole order.
  enum :applies_to, { all: 0, services: 1, parts: 2 }, prefix: :applies_to

  normalizes :name, with: ->(name) { name.strip.squeeze(" ") }

  validates :name, presence: true
  validates :value, numericality: { greater_than: 0 }
  validates :value, numericality: { less_than_or_equal_to: 100 }, if: :percentage?

  scope :active, -> { where(active: true) }

  # The part of an order this discount is taken from.
  def base_for(works_total:, parts_total:)
    case applies_to
    when "services" then works_total
    when "parts" then parts_total
    else works_total + parts_total
    end
  end

  # Never more than the base it comes off — a 10 000 грн voucher against
  # 1 200 грн of work takes 1 200, not the order into the negative.
  def amount_for(works_total:, parts_total:)
    base = base_for(works_total: works_total, parts_total: parts_total)
    raw = percentage? ? base * value / 100 : value

    [ raw, base ].min.round(2)
  end
  scope :ordered, -> { order(:name) }
end
