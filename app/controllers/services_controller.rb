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
      respond_to do |format|
        format.turbo_stream { load_index_data_and_reset_form; render :refresh }
        format.html { redirect_to services_path(category_id: params[:category_id]), notice: "Роботу додано." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { load_index_data; render :index, status: :unprocessable_entity }
      end
    end
  end

  def update
    @service = Service.find(params[:id])

    if @service.update(service_params)
      respond_to do |format|
        format.turbo_stream { load_index_data_and_reset_form; render :refresh }
        format.html { redirect_to services_path(category_id: params[:category_id]), notice: "Роботу оновлено." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { load_index_data; render :index, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    Service.find(params[:id]).update!(active: false)

    respond_to do |format|
      format.turbo_stream do
        load_index_data
        render turbo_stream: turbo_stream.update("services_rows", partial: "rows", locals: { services: @services, category_id: params[:category_id] })
      end
      format.html { redirect_to services_path(category_id: params[:category_id]), notice: "Роботу архівовано." }
    end
  end

  # Reused by the order "Додати роботу" modal (P3) to look up catalog items as-you-type.
  def search
    scope = Service.active.search(params[:q])
    scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
    @services = scope.ordered.limit(10)
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
      @services = Service.active.search(params[:q]).ordered
      @services = @services.where(category: @selected_category) if @selected_category
    end

    # After a successful create/update, the side-panel form goes back to
    # "Додати" mode (mirrors the html fallback's redirect to the plain index,
    # which never carries ?edit=).
    def load_index_data_and_reset_form
      load_index_data
      @service = Service.new
    end
end
