class PartsController < ApplicationController
  # D38: open to every role. A mechanic needs the price list to build an order
  # and to quote a customer, and the shop decided they may maintain it too.

  def index
    load_index_data
    @part = params[:edit].present? ? Part.find(params[:edit]) : Part.new
  end

  def create
    @part = Part.new(part_params)

    if @part.save
      respond_to do |format|
        format.turbo_stream { load_index_data_and_reset_form; render :refresh }
        format.html { redirect_to parts_path(category_id: params[:category_id]), notice: "Запчастину додано." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { load_index_data; render :index, status: :unprocessable_entity }
      end
    end
  end

  def update
    @part = Part.find(params[:id])

    if @part.update(part_params)
      respond_to do |format|
        format.turbo_stream { load_index_data_and_reset_form; render :refresh }
        format.html { redirect_to parts_path(category_id: params[:category_id]), notice: "Запчастину оновлено." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { load_index_data; render :index, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    Part.find(params[:id]).update!(active: false)

    respond_to do |format|
      format.turbo_stream do
        load_index_data
        render turbo_stream: turbo_stream.update("parts_rows", partial: "rows", locals: { parts: @parts, category_id: params[:category_id] })
      end
      format.html { redirect_to parts_path(category_id: params[:category_id]), notice: "Запчастину архівовано." }
    end
  end

  # Reused by the order "Додати деталь / матеріал" modal (P3) to look up catalog items as-you-type.
  def search
    scope = Part.active.search(params[:q])
    scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
    @parts = scope.ordered.limit(10)
    @order = Order.find(params[:order_id]) if params[:order_id].present?
    render layout: false
  end

  private
    def part_params
      params.expect(part: %i[ name category_id base_price sku supplier_id purchase_price ])
    end

    def load_index_data
      @categories = Category.part.active.ordered
      @selected_category = @categories.find_by(id: params[:category_id])
      @parts = Part.active.search(params[:q]).ordered
      @parts = @parts.where(category: @selected_category) if @selected_category
      @suppliers = Supplier.active.ordered
    end

    def load_index_data_and_reset_form
      load_index_data
      @part = Part.new
    end
end
