class StockMovementsController < ApplicationController
  require_role :admin, :owner
  layout "modal", only: %i[ new create ]

  # :consumption is system-only (Orders::Close) — never a manually-picked kind here.
  ALLOWED_KINDS = %w[ receipt write_off adjustment ].freeze

  before_action :set_part

  def new
    @movement = @part.stock_movements.new(kind: :receipt)
  end

  def create
    unless ALLOWED_KINDS.include?(params.dig(:stock_movement, :kind))
      @movement = @part.stock_movements.new
      @movement.errors.add(:kind, "недійсне значення")
      render :new, status: :unprocessable_entity
      return
    end

    @movement = @part.stock_movements.new(movement_params)
    @movement.user = Current.user
    normalize_quantity_sign

    if @movement.save
      redirect_to parts_path, notice: "Рух складу записано."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def set_part
      @part = Part.find(params[:part_id])
    end

    def movement_params
      params.expect(stock_movement: %i[ kind quantity note ])
    end

    # kind is metadata for the audit trail; the sign on quantity is what's
    # authoritative (Parts::RecalculateStock just sums it) — receipt/write_off
    # always push the sign in their own direction regardless of how the user
    # typed the number; adjustment is taken exactly as entered, either sign.
    def normalize_quantity_sign
      return if @movement.quantity.nil?

      case @movement.kind
      when "receipt" then @movement.quantity = @movement.quantity.abs
      when "write_off" then @movement.quantity = -@movement.quantity.abs
      end
    end
end
