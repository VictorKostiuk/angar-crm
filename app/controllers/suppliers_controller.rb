class SuppliersController < ApplicationController
  require_role :admin, :owner

  def index
    load_index_data
    @supplier = params[:edit].present? ? Supplier.find(params[:edit]) : Supplier.new
  end

  def create
    @supplier = Supplier.new(supplier_params)

    if @supplier.save
      redirect_to suppliers_path, notice: "Постачальника додано."
    else
      load_index_data
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @supplier = Supplier.find(params[:id])

    if @supplier.update(supplier_params)
      redirect_to suppliers_path, notice: "Постачальника оновлено."
    else
      load_index_data
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    Supplier.find(params[:id]).update!(active: false)
    redirect_to suppliers_path, notice: "Постачальника архівовано."
  end

  private
    def supplier_params
      params.expect(supplier: %i[ name phone email notes ])
    end

    def load_index_data
      @suppliers = Supplier.active.ordered
    end
end
