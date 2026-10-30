class SalesController < ApplicationController
  # Every role sells over the counter — mechanics earn a commission on it
  # (D40), so gating this to owner/admin would make that rate unreachable.
  layout "modal", only: %i[ new create ]

  def index
    @period = PeriodFilter.new(**period_params)
    @sales = Sale.in_range(@period.range).includes(:sold_by, :client, sale_items: :part).ordered
    @total = @sales.sum(&:total)
    @commission_total = @sales.sum(&:commission)
  end

  def new
    @sale = Sale.new(sold_at: Time.current, sold_by: Current.user)
    @sale.sale_items.build
    load_form_data
  end

  def create
    @sale = Sale.new(sale_params)
    # Whoever rang it up at the counter is not always who is logged in on the
    # shop tablet — the seller is picked on the form and earns the commission.
    # Defaults to the current user when the field is left out.
    @sale.sold_by ||= Current.user
    @sale.sold_at ||= Time.current

    if @sale.save
      Sales::RecalculateTotal.call(@sale)
      redirect_to sales_path, notice: "Продаж записано."
    else
      load_form_data
      render "shared/modal_form_error", locals: { form_template: "sales/new" }, status: :unprocessable_entity
    end
  end

  private
    def period_params
      params.permit(:period, :from, :to).to_h.symbolize_keys
    end

    def load_form_data
      @parts = Part.active.ordered.includes(:category)
      @clients = Client.order(:name)
      @sellers = User.active.order(:name)
    end

    def sale_params
      params.expect(sale: [ :client_id, :sold_by_id, :note, { sale_items_attributes: [ [ :part_id, :name, :quantity, :price ] ] } ])
    end
end
