class DiscountsController < ApplicationController
  require_role :owner

  def index
    load_index_data
    @discount = params[:edit].present? ? Discount.find(params[:edit]) : Discount.new
  end

  def create
    @discount = Discount.new(discount_params)

    if @discount.save
      respond_to do |format|
        format.turbo_stream { load_index_data_and_reset_form; render :refresh }
        format.html { redirect_to discounts_path, notice: "Знижку додано." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { load_index_data; render :index, status: :unprocessable_entity }
      end
    end
  end

  def update
    @discount = Discount.find(params[:id])

    if @discount.update(discount_params)
      respond_to do |format|
        format.turbo_stream { load_index_data_and_reset_form; render :refresh }
        format.html { redirect_to discounts_path, notice: "Знижку оновлено." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { load_index_data; render :index, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    Discount.find(params[:id]).update!(active: false)

    respond_to do |format|
      format.turbo_stream do
        load_index_data
        render turbo_stream: turbo_stream.update("discounts_rows", partial: "rows", locals: { discounts: @discounts })
      end
      format.html { redirect_to discounts_path, notice: "Знижку архівовано." }
    end
  end

  private
    def discount_params
      params.expect(discount: %i[ name kind value applies_to ])
    end

    def load_index_data
      @discounts = Discount.active.ordered
    end

    def load_index_data_and_reset_form
      load_index_data
      @discount = Discount.new
    end
end
