class OrderStatusChange < ApplicationRecord
  belongs_to :order
  belongs_to :user

  validates :from_status, :to_status, presence: true
  validates :comment, length: { maximum: 200 }
end
