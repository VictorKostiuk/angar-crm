class StockMovementsController < ApplicationController
  require_role :admin, :owner

  def create
    @movement = StockMovement.new(movement_params.merge(user: Current.user))
    # The ledger is signed: a write-off removes stock, so its quantity is
    # negative however the form phrased it. Receipts and adjustments are taken
    # as typed — an adjustment can legitimately go either way.
    @movement.quantity = -@movement.quantity.abs if @movement.write_off?

    if @movement.save
      redirect_to stock_path(category_id: params[:category_id], q: params[:q]), notice: "Рух складу записано."
    else
      redirect_to stock_path(category_id: params[:category_id], q: params[:q]),
                  alert: @movement.errors.full_messages.to_sentence.presence || "Не вдалося записати рух складу."
    end
  end

  private
    def movement_params
      params.expect(stock_movement: %i[ part_id kind quantity note ])
    end
end
