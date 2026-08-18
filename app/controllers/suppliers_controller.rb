class SuppliersController < ApplicationController
  require_role :admin, :owner

  def index
    load_index_data
    @supplier = params[:edit].present? ? Supplier.find(params[:edit]) : Supplier.new
  end

  def create
    @supplier = Supplier.new(supplier_params)

    if @supplier.save
      respond_to do |format|
        format.turbo_stream { load_index_data_and_reset_form; render :refresh }
        format.html { redirect_to suppliers_path, notice: "Постачальника додано." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { load_index_data; render :index, status: :unprocessable_entity }
      end
    end
  end

  def update
    @supplier = Supplier.find(params[:id])

    if @supplier.update(supplier_params)
      respond_to do |format|
        format.turbo_stream { load_index_data_and_reset_form; render :refresh }
        format.html { redirect_to suppliers_path, notice: "Постачальника оновлено." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { load_index_data; render :index, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    Supplier.find(params[:id]).update!(active: false)

    respond_to do |format|
      format.turbo_stream do
        load_index_data
        render turbo_stream: turbo_stream.update("suppliers_rows", partial: "rows", locals: { suppliers: @suppliers })
      end
      format.html { redirect_to suppliers_path, notice: "Постачальника архівовано." }
    end
  end

  private
    def supplier_params
      params.expect(supplier: %i[ name phone email notes ])
    end

    def load_index_data
      @suppliers = Supplier.active.ordered
    end

    def load_index_data_and_reset_form
      load_index_data
      @supplier = Supplier.new
    end
end
