class ServicesController < ApplicationController
  # search is exempt: P3's add-work modal calls it on every keystroke, and a
  # mechanic building an order must be able to search the catalog even
  # though they can't edit it (§7).
  require_role :admin, :owner, except: :search

  def index
    load_index_data
    @service = params[:edit].present? ? Service.find(params[:edit]) : Service.new
  end

  def create
    @service = Service.new(service_params)

    if @service.save
      redirect_to services_path(category_id: params[:category_id]), notice: "Роботу додано."
    else
      load_index_data
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @service = Service.find(params[:id])

    if @service.update(service_params)
      redirect_to services_path(category_id: params[:category_id]), notice: "Роботу оновлено."
    else
      load_index_data
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    Service.find(params[:id]).update!(active: false)
    redirect_to services_path(category_id: params[:category_id]), notice: "Роботу архівовано."
  end

  # Reused by the order "Додати роботу" modal (P3) to look up catalog items as-you-type.
  def search
    @services = Service.active.search(params[:q]).ordered.limit(10)
    @order = Order.find(params[:order_id]) if params[:order_id].present?
    render layout: false
  end

  private
    def service_params
      params.expect(service: %i[ name category_id base_price ])
    end

    def load_index_data
      @categories = Category.service.active.ordered
      @selected_category = @categories.find_by(id: params[:category_id])
      @services = Service.active.ordered
      @services = @services.where(category: @selected_category) if @selected_category
    end
end
