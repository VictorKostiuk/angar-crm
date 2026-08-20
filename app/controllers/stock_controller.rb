class StockController < ApplicationController
  # Receiving goods and writing them off is inventory management, so this stays
  # owner/admin — unlike the Запчастини price list (D38), which every role uses
  # while building an order.
  require_role :admin, :owner

  def index
    load_index_data
  end

  private
    def load_index_data
      @categories = Category.part.active.ordered
      @selected_category = @categories.find_by(id: params[:category_id])
      @parts = Part.active.search(params[:q]).ordered.includes(:supplier, :category)
      @parts = @parts.where(category: @selected_category) if @selected_category
      @movements = StockMovement.includes(:part, :user, :order).order(created_at: :desc).limit(50)
    end
end
